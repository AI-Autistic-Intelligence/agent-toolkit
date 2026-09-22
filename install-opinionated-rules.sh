#!/usr/bin/env bash
#
# Symlink every rule from this repo into agent config directories, in two
# layers:
#
#   1. the agent-neutral dir (default: ~/.agents/rules) gets one link per
#      rule file, pointing into this repo;
#   2. the agent's own rules dir (default: ~/.claude/rules) gets links
#      pointing at the corresponding agent-neutral entries.
#
# The rules are the toolkit's opinionated layer — always-on behavior
# policies. Skills never depend on them; installing rules is a deliberate
# opt-in, which is why this lives apart from ./install.sh (skills).
#
# Each rule (rules/*.md) is linked individually, so you can also link just
# the ones you want by hand instead of running this.
#
# Re-running converges: correct links are left alone, links owned by this
# repo that point elsewhere (e.g. the old direct layout) are re-pointed, and
# broken links owned by this repo are pruned. To wire up another agent, run
# again with its --rules-dir.
#
# Usage:
#   ./install-opinionated-rules.sh [options]
#
# Options:
#   --agents-dir DIR   Agent-neutral directory   (default: ~/.agents)
#   --rules-dir DIR    Agent's rules directory   (default: ~/.claude/rules)
#   --force            Overwrite real files/dirs and foreign symlinks
#   --no-auto-update   Do not register the daily self-update hook (persists)
#   --auto-update      Register it again after --no-auto-update
#   -h, --help         Show this help
#
# When Claude Code is detected, this also registers a hook that fast-forwards
# this clone once a day and re-runs the installers: docs/auto-update.md.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_DIR_LOGICAL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "${REPO_DIR}/lib/install-utils.sh"

AGENTS_DIR="${HOME}/.agents"
CUSTOM_RULES_DIR=""
AGENT_LIST=()
FORCE=0
AUTO_UPDATE=""
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
TARGET_FLAG=--rules-dir

usage() {
  cat <<'EOF'
Symlink every rule from this repo into agent config directories, in two
layers:

  1. the agent-neutral dir (default: ~/.agents/rules) gets one link per
     rule file, pointing into this repo;
  2. the agent's own rules dir (default: ~/.claude/rules) gets links
     pointing at the corresponding agent-neutral entries.

The rules are the toolkit's opinionated layer — always-on behavior
policies. Skills never depend on them; installing rules is a deliberate
opt-in, which is why this lives apart from ./install.sh (skills).

Each rule (rules/*.md) is linked individually, so you can also link just
the ones you want by hand instead of running this.

Re-running converges: correct links are left alone, links owned by this
repo that point elsewhere (e.g. the old direct layout) are re-pointed, and
broken links owned by this repo are pruned. To wire up another agent, run
again with its --rules-dir.

Usage:
  ./install-opinionated-rules.sh [options]

Options:
  --agents-dir DIR   Agent-neutral directory   (default: ~/.agents)
  --rules-dir DIR    Specific rules directory (overrides agents.json)
  --agent NAME       Install for specific agent from agents.json
  --all-agents       Install for all configured agents (default behavior)
  --force            Overwrite real files/dirs and foreign symlinks
  --no-auto-update   Do not register the daily self-update hook (persists)
  --auto-update      Register it again after --no-auto-update
  -h, --help         Show this help

When Claude Code is detected, this also registers a hook that fast-forwards
this clone once a day and re-runs the installers: docs/auto-update.md.
EOF
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --agents-dir) AGENTS_DIR="$2"; shift 2 ;;
    --rules-dir)  CUSTOM_RULES_DIR="$2"; shift 2 ;;
    --agent) AGENT_LIST+=("$2"); shift 2 ;;
    --all-agents) AGENT_LIST=(); shift ;;
    --force) FORCE=1; shift ;;
    --no-auto-update) AUTO_UPDATE=off; shift ;;
    --auto-update) AUTO_UPDATE=on; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

resolve_agents_dir

# Phase 1: populate the agent-neutral dir with links into the repo.
# Pruning the agents dir first breaks downstream agent links for removed
# items, so the phase-2 prune can catch them in the same run.
echo "Agents dir -> ${AGENTS_DIR}/rules"
mkdir -p "${AGENTS_DIR}/rules"
prune_dir "${AGENTS_DIR}/rules"
begin_phase
for rule in "${REPO_DIR}"/rules/*.md; do
  [ -e "$rule" ] || continue
  link_one "$rule" "${AGENTS_DIR}/rules"
done
end_phase

# Phase 2: populate the agent's dir with links to the agent-neutral entries.
TARGETS=()

if [ -n "$CUSTOM_RULES_DIR" ]; then
  TARGETS+=("$CUSTOM_RULES_DIR")
elif [ "${#AGENT_LIST[@]}" -gt 0 ]; then
  for agent in "${AGENT_LIST[@]}"; do
    agent_dir="$(get_agent_config_val "$agent" "rules_dir")"
    if [ -n "$agent_dir" ]; then
      TARGETS+=("$(expand_path "$agent_dir")")
    else
      echo "Warning: Agent '$agent' not found in agents.json or has no rules_dir." >&2
    fi
  done
else
  agents="$(get_configured_agents)"
  if [ -n "$agents" ]; then
    while IFS= read -r agent; do
      [ -n "$agent" ] || continue
      agent_dir="$(get_agent_config_val "$agent" "rules_dir")"
      [ -n "$agent_dir" ] && TARGETS+=("$(expand_path "$agent_dir")")
    done <<< "$agents"
  else
    TARGETS+=("${HOME}/.claude/rules")
  fi
fi

for RULES_DIR in "${TARGETS[@]}"; do
  echo "Rules -> ${RULES_DIR}"
  mkdir -p "$RULES_DIR"
  TARGET_DIR="$(cd "$RULES_DIR" && pwd -P)"
  if [ "$TARGET_DIR" = "${AGENTS_DIR}/rules" ]; then
    echo "  ok     (this is the agents dir itself; already populated)"
  else
    prune_dir "$RULES_DIR"
    begin_phase
    for rule in "${REPO_DIR}"/rules/*.md; do
      [ -e "$rule" ] || continue
      src="${AGENTS_DIR}/rules/$(basename "$rule")"
      if [ ! -e "$src" ]; then
        count_skip
        echo "  skip   $(basename "$rule") (no usable entry in agents dir)"
        continue
      fi
      link_one "$src" "$RULES_DIR"
    done
    end_phase
  fi
  finish_auto_update
done

report_install_health
echo "Done."
