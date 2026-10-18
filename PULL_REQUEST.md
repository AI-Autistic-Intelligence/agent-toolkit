# feat: add multi-agent installation support via agents.json

## Summary

This PR introduces multi-agent installation support for `install.sh` and `install-opinionated-rules.sh` via a centralized `agents.json` configuration file. 

Instead of defaulting hardcoded installation paths to Claude Code alone (`~/.claude/skills`), installer scripts can now dynamically discover and install skills/rules across multiple configured AI agents (e.g. Claude Code, Antigravity) in a single run.

---

## What's Changed

### 1. Centralized Agent Configuration (`agents.json`)
Added `agents.json` at the root of the repository to define target directories for supported AI agents:
```json
{
  "agents": {
    "claude": {
      "skills_dir": "~/.claude/skills",
      "rules_dir": "~/.claude/rules",
      "auto_update": true
    },
    "antigravity": {
      "skills_dir": "~/.gemini/config/skills",
      "rules_dir": "~/.gemini/config/rules",
      "auto_update": false
    }
  }
}
```

### 2. Multi-Agent CLI Flags (`install.sh` & `install-opinionated-rules.sh`)
- `--agent NAME`: Install skills/rules for a specific agent defined in `agents.json` (can be specified multiple times).
- `--all-agents`: Install skills/rules for all agents configured in `agents.json` (default behavior when `agents.json` is present).
- `--skills-dir DIR` / `--rules-dir DIR`: Maintained full backwards compatibility; providing an explicit directory overrides `agents.json`.

### 3. Utility Helpers (`lib/install-utils.sh`)
- `get_configured_agents()`: Parses agent identifiers from `agents.json` with multi-runtime fallback (`python3`, `node`, or `jq`).
- `get_agent_config_val()`: Fetches key properties (`skills_dir`, `rules_dir`) for a target agent.
- `expand_path()`: Safely expands `~` paths and handles Windows/cygpath path conversions.

---

## How to Test

1. **Default Multi-Agent Install:**
   ```bash
   ./install.sh
   ```
   *Verify that skills are linked into both `~/.claude/skills` and `~/.gemini/config/skills`.*

2. **Target Specific Agent:**
   ```bash
   ./install.sh --agent antigravity
   ```
   *Verify that skills are linked only into `~/.gemini/config/skills`.*

3. **Explicit Custom Directory Override:**
   ```bash
   ./install.sh --skills-dir /tmp/custom-skills
   ```
   *Verify that custom directory override still takes precedence.*

4. **Rules Installation across Agents:**
   ```bash
   ./install-opinionated-rules.sh
   ```
   *Verify that opinionated rules are distributed across all configured agents.*
