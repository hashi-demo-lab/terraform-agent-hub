# CLAUDE.md — terraform-agent-hub

## Project Overview

Central hub repo for shared Claude Code agents, skills, scripts, and markdown artifact templates. Changes pushed here are automatically synced to downstream workflow repos via GitHub Actions PRs.

## Architecture

- **Content directories** (`agents/`, `skills/`, `scripts/`, `templates/`) are flat — no per-repo subdirectories
- **Filtering** is handled entirely by `sync-config/sync-config.yaml` profiles, includes, and excludes
- **Sync mechanism** uses a reusable composite action (`.github/actions/sync-files/`) shared by both workflows
- **Three workflows**: push-triggered lint→sync pipeline, daily drift detection, and PR lint gate
- **Hub-only directories** (`reference/`, `hooks/`) are not synced — they support content authoring and validation locally

## Key Files

- `sync-config/sync-config.yaml` — central mapping config (hub → downstream repos)
- `.github/actions/sync-files/parse_config.py` — YAML config parser, outputs JSON
- `.github/actions/sync-files/sync.sh` — core sync logic (clone, rsync, diff, PR)
- `.github/actions/sync-files/action.yaml` — composite action wiring inputs/outputs
- `.github/workflows/sync-on-push.yaml` — push-triggered pipeline: lint → detect → sync (matrix fan-out)
- `.github/workflows/sync-drift-detection.yaml` — scheduled daily drift detection
- `.github/workflows/lint.yaml` — pre-commit CI gate on PRs
- `hooks/validate_skills.py` — SKILL.md spec validator (pre-commit hook)
- `hooks/validate_agents.py` — agent .md validator (pre-commit hook)
- `reference/skills-authoring-guide.md` — comprehensive skills authoring spec
- `reference/agent-authoring-guide.md` — agent authoring conventions

## Conventions

### Content Files
- Agents: one `.md` file per agent in `agents/`
- Skills: one directory per skill in `skills/`, each containing `SKILL.md`
- Scripts: executable `.sh` files in `scripts/` with usage comments
- Templates: markdown artifact templates in `templates/` (plans, specs, reports, checklists, etc.)

### Sync Config
- Group repos into profiles when they share the same mappings
- Use standalone for one-off repos
- Per-directory READMEs are globally excluded from sync (hub-only docs)
- Test config changes by running `parse_config.py` locally

### Workflows
- Both sync workflows use the same composite action — changes to sync logic go in one place
- `SYNC_PAT` secret must have `repo` and `workflow` scopes
- Push workflow runs lint first, then detect, then sync — sync is blocked if lint fails
- Push workflow uses incremental mode (only syncs affected repos/files)
- Drift detection uses full mode (compares everything)
- `lint.yaml` runs only on PRs; push-to-main linting is handled inside `sync-on-push.yaml`
- All workflows write job summaries to `$GITHUB_STEP_SUMMARY` for clear reporting in the Actions UI

### Code Style
- Shell scripts: `bash` with `set -euo pipefail`, POSIX-compatible where possible
- Python: Python 3.11+, type hints, minimal dependencies (only `pyyaml`)
- YAML: 2-space indent, quoted strings for values that could be misinterpreted

### Pre-commit Hooks
- Install: `pre-commit install` (one-time setup)
- Run all: `pre-commit run --all-files`
- Custom validators in `hooks/` follow the same style as `parse_config.py`
- Hooks use `::error::` / `::warning::` annotations for GitHub Actions CI compatibility
- Authoring guides in `reference/` document the rules that hooks enforce

## Commands

```bash
# Run all pre-commit hooks
pre-commit run --all-files

# Run skill validator directly
python3 hooks/validate_skills.py

# Run agent validator directly
python3 hooks/validate_agents.py

# Validate sync config
python3 -c "import yaml; yaml.safe_load(open('sync-config/sync-config.yaml'))"

# Test config parser locally
CONFIG_PATH=sync-config/sync-config.yaml \
DOWNSTREAM_REPO=your-org/downstream-repo-1 \
CHANGED_FILES='["agents/plan-reviewer.md"]' \
SYNC_MODE=incremental \
python3 .github/actions/sync-files/parse_config.py

# Test config parser (full sync mode)
CONFIG_PATH=sync-config/sync-config.yaml \
DOWNSTREAM_REPO=your-org/downstream-repo-1 \
CHANGED_FILES='[]' \
SYNC_MODE=full \
python3 .github/actions/sync-files/parse_config.py
```
