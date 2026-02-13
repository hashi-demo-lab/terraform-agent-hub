# CLAUDE.md — terraform-agent-hub

Hub repo that syncs shared agents, skills, scripts, and templates to downstream repos via GitHub Actions PRs. See README.md for full documentation.

## Key Paths

- `sync-config/sync-config.yaml` — defines which repos get which content
- `.github/workflows/sync-on-push.yaml` — lint → detect → sync pipeline (push to main)
- `.github/workflows/sync-drift-detection.yaml` — daily full-sync drift check
- `.github/workflows/lint.yaml` — pre-commit gate (PRs only)
- `.github/actions/sync-files/` — composite action: `parse_config.py`, `sync.sh`, `action.yaml`
- `hooks/validate_skills.py` — SKILL.md validator
- `hooks/validate_agents.py` — agent .md validator
- `reference/` — authoring guides (skills, agents) — hub-only, not synced

## Content Rules

- **Agents**: `agents/<name>.md` — kebab-case filename, non-empty
- **Skills**: `skills/<name>/SKILL.md` — YAML frontmatter with `name` (kebab-case) + `description`, under 500 lines
- **Scripts**: `scripts/<name>.sh` — executable, `set -euo pipefail`, passes shellcheck
- **Templates**: `templates/<name>.md` — use `[BRACKETS]` for human content, `{{DOUBLE_BRACES}}` for machine values

## Code Style

- Shell: `bash`, `set -euo pipefail`, quote variables
- Python: 3.11+, type hints, `yaml.safe_load()` only, minimal deps (`pyyaml`)
- YAML: 2-space indent, quoted ambiguous values

## Workflow Rules

- Push to main runs: lint → detect → sync. Sync is blocked if lint fails.
- `lint.yaml` runs only on PRs. Push linting lives inside `sync-on-push.yaml`.
- Both sync workflows use the same composite action — change sync logic in one place.
- `SYNC_PAT` secret needs `repo` + `workflow` scopes.
- All workflows write summaries to `$GITHUB_STEP_SUMMARY`.

## Commands

```bash
# Validate everything
pre-commit run --all-files

# Run validators directly
python3 hooks/validate_skills.py
python3 hooks/validate_agents.py

# Test sync config parser
CONFIG_PATH=sync-config/sync-config.yaml \
DOWNSTREAM_REPO=your-org/downstream-repo-1 \
CHANGED_FILES='["agents/plan-reviewer.md"]' \
SYNC_MODE=incremental \
python3 .github/actions/sync-files/parse_config.py
```
