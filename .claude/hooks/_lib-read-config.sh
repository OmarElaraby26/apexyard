#!/bin/bash
# _lib-read-config.sh — shared reader for .claude/project-config.*.json
#
# Source this library from any hook or skill that needs to read project config.
# Defaults ship at .claude/project-config.defaults.json (committed, upstream-
# maintained). User overrides live at .claude/project-config.json (optional;
# each fork decides whether to commit or gitignore it).
#
# Merge strategy: SHALLOW at the top level. If the user defines `ticket`, their
# entire `ticket` subtree replaces the default. To extend a subtree, copy the
# default fields and add/modify. This keeps merge behaviour predictable without
# requiring a deep-merge jq function, and matches the "config file as a whole"
# mental model most teams expect.
#
# Usage:
#   source "$(git rev-parse --show-toplevel)/.claude/hooks/_lib-read-config.sh"
#   config_get '.ticket.prefix_whitelist[]'
#   config_get '.branch.type_whitelist[]'
#   config_get '.ticket.label_priority_scheme'
#
# Silent fallback behaviour:
#   - No defaults file present: emit '{}' and an error on stderr. Callers should
#     treat config_get as "unknown" and apply their own safety.
#   - jq not installed: emit '{}' and a one-time warning on stderr.

# ------------------------------------------------------------------------------
# Internal state: cache merged config per-process so repeated reads are cheap.
# ------------------------------------------------------------------------------
_CONFIG_CACHE=""
_CONFIG_WARNED_NO_JQ=""
_CONFIG_ROOT_CACHE=""

# _config_repo_root: resolve the directory that holds .claude/project-config.*.
#
# When the operator is inside a managed-project workspace clone at
# workspace/<project>/, `git rev-parse --show-toplevel` returns the project
# clone's git root — NOT the ops fork. The project clone usually has no
# .claude/project-config.json (or a different one), so config_get falls back
# to the framework defaults file which doesn't exist either, and tracker.kind
# silently resolves to "gh" even when the operator configured Linear / Jira /
# Asana / custom at the ops-fork level (me2resh/apexyard#310).
#
# Fix: walk up looking for the ops-fork anchor (.apexyard-fork marker for
# split-portfolio v2, or onboarding.yaml + apexyard.projects.yaml for v1)
# FIRST. Fall back to `git rev-parse --show-toplevel` only when no ops fork
# is found anywhere above $PWD — preserves the legacy behaviour for adopters
# running these hooks outside an apexyard fork entirely (bare clones, CI
# sandboxes, etc.).
#
# Result is cached per-process — the walk is cheap but called by every
# config_get invocation, so caching matches the _CONFIG_CACHE pattern.
_config_repo_root() {
  if [ -n "$_CONFIG_ROOT_CACHE" ]; then
    echo "$_CONFIG_ROOT_CACHE"
    return 0
  fi
  local root=""
  # Try the ops-fork resolver first. _lib-ops-root.sh lives next to this
  # file in .claude/hooks/, so locate it via BASH_SOURCE — not via
  # `git rev-parse` (which would defeat the whole point of this fix).
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -f "$lib_dir/_lib-ops-root.sh" ]; then
    # shellcheck source=/dev/null
    . "$lib_dir/_lib-ops-root.sh"
    if command -v resolve_ops_root >/dev/null 2>&1; then
      root=$(resolve_ops_root "$PWD")
    fi
  fi
  # Fallback: legacy behaviour for non-apexyard environments. Lets these
  # hooks remain usable in bare clones / CI sandboxes that don't ship the
  # ops-fork anchors.
  if [ -z "$root" ]; then
    root=$(git rev-parse --show-toplevel 2>/dev/null)
  fi
  _CONFIG_ROOT_CACHE="$root"
  echo "$root"
}

_config_defaults_file() {
  local root
  root=$(_config_repo_root)
  [ -n "$root" ] && echo "$root/.claude/project-config.defaults.json"
}

_config_overrides_file() {
  local root
  root=$(_config_repo_root)
  [ -n "$root" ] && echo "$root/.claude/project-config.json"
}

# _config_workspace_overrides_file: when CWD's git toplevel sits inside a
# registered managed-project workspace under <ops_root>/workspace/<name>/,
# return that workspace's .claude/project-config.json path (if present).
# Returns empty string when:
#   - CWD git toplevel isn't a workspace clone (e.g. operator inside ops fork),
#   - the workspace isn't registered in apexyard.projects.yaml,
#   - the workspace's .claude/project-config.json doesn't exist.
#
# This is the third layer of config resolution added in apexyard#11 (AgDR-0053).
# Without it, .ci.require_to_exist and any other project-scoped flag set in
# `workspace/<name>/.claude/project-config.json` is dead config — the operator
# follows the runbook's guidance to commit the flag to the project's repo, but
# the merge-gate hook never reads from there.
_config_workspace_overrides_file() {
  local ops_root pwd_toplevel
  ops_root=$(_config_repo_root)
  [ -z "$ops_root" ] && return 0
  pwd_toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
  [ -z "$pwd_toplevel" ] && return 0
  # Same path? CWD is at the ops fork itself — no workspace layer applies.
  [ "$pwd_toplevel" = "$ops_root" ] && return 0
  # Is the CWD toplevel inside <ops_root>/workspace/<name>/?
  case "$pwd_toplevel" in
    "$ops_root/workspace/"*) ;;
    *) return 0 ;;
  esac
  # Extract <name> (first path component after workspace/).
  local rel_path name
  rel_path="${pwd_toplevel#"$ops_root"/workspace/}"
  name="${rel_path%%/*}"
  [ -z "$name" ] && return 0
  # Only honour the layer if the project is registered in the registry. This
  # avoids surprises if a stray dir lives under workspace/ that isn't managed.
  if [ -f "$ops_root/apexyard.projects.yaml" ]; then
    if command -v yq >/dev/null 2>&1; then
      local registered
      registered=$(yq eval ".projects[] | select(.name == \"${name}\") | .name" \
        "$ops_root/apexyard.projects.yaml" 2>/dev/null)
      [ -z "$registered" ] && return 0
    else
      # Greppy fallback: look for `- name: <name>` at any indent.
      if ! grep -qE "^[[:space:]]*-?[[:space:]]*name:[[:space:]]+[\"']?${name}[\"']?[[:space:]]*$" \
           "$ops_root/apexyard.projects.yaml" 2>/dev/null; then
        return 0
      fi
    fi
  fi
  local candidate="$pwd_toplevel/.claude/project-config.json"
  [ -f "$candidate" ] && echo "$candidate"
}

_config_load() {
  # Check jq availability once per process.
  if ! command -v jq >/dev/null 2>&1; then
    if [ -z "$_CONFIG_WARNED_NO_JQ" ]; then
      echo "WARN: jq not installed; project config unavailable. Install jq to enable config-driven hooks." >&2
      _CONFIG_WARNED_NO_JQ=1
    fi
    echo '{}'
    return 0
  fi

  local defaults overrides workspace_overrides
  defaults=$(_config_defaults_file)
  overrides=$(_config_overrides_file)
  workspace_overrides=$(_config_workspace_overrides_file)

  if [ -z "$defaults" ] || [ ! -f "$defaults" ]; then
    # No defaults file — repo may not be an apexyard fork (e.g. project-inside-workspace).
    echo '{}'
    return 0
  fi

  # Three-layer merge: defaults < ops-fork override < workspace override.
  # `jq -s '.[0] * .[1] * .[2]'` performs successive shallow merges, with
  # later operands winning at top-level keys. Missing layers default to {}.
  local ops_layer="{}"
  local ws_layer="{}"
  [ -f "$overrides" ] && ops_layer=$(cat "$overrides")
  [ -n "$workspace_overrides" ] && [ -f "$workspace_overrides" ] && ws_layer=$(cat "$workspace_overrides")

  jq -s '.[0] * .[1] * .[2]' \
    "$defaults" \
    <(printf '%s' "$ops_layer") \
    <(printf '%s' "$ws_layer") \
    2>/dev/null || cat "$defaults"
}

# ------------------------------------------------------------------------------
# Public: config_get <jq-filter>
#   Outputs the result of applying the filter to the merged config.
#   Returns an empty string (not an error) when the filter matches nothing.
# ------------------------------------------------------------------------------
config_get() {
  local filter="${1:-.}"
  if [ -z "$_CONFIG_CACHE" ]; then
    _CONFIG_CACHE=$(_config_load)
  fi
  if command -v jq >/dev/null 2>&1; then
    echo "$_CONFIG_CACHE" | jq -r "$filter" 2>/dev/null
  else
    return 0
  fi
}

# ------------------------------------------------------------------------------
# Public: config_get_or <jq-filter> <fallback>
#   Like config_get, but returns <fallback> if the filter yields an empty
#   string, "null", or an error. Useful for single-value lookups with sensible
#   in-code defaults (e.g. when a hook runs outside an apexyard repo).
# ------------------------------------------------------------------------------
config_get_or() {
  local filter="$1"
  local fallback="$2"
  local value
  value=$(config_get "$filter")
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    echo "$fallback"
  else
    echo "$value"
  fi
}
