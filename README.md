# terraform-agent-hub

Central hub for shared Claude Code agents, skills, scripts, and markdown artifact templates synced to downstream workflow repos.

## Problem

You manage multiple workflow template repos (`ai-iac-module-template`, `ai-iac-consumer-template`) that share common Claude Code agents, skills, scripts, and templates. When you update one of these shared files in a single repo, the others fall out of date. This repo is the single source of truth, with automated GitHub Actions to sync changes to all downstream repos via PRs.

## Architecture

```
terraform-agent-hub (this repo)
    │
    ├── agents/          ──→  .claude/agents/    (downstream)
    ├── skills/          ──→  .claude/skills/    (downstream)
    ├── scripts/         ──→  scripts/           (downstream)
    └── templates/       ──→  templates/         (downstream)
    │
    ├── reference/            (hub-only authoring guides)
    ├── hooks/                (hub-only pre-commit validators)
    ├── sync-config.yaml      (mapping config)
    │
    └── GitHub Actions
         ├── sync-on-push     (lint → detect → sync PRs to downstream)
         ├── drift-detection  (daily check → PRs if drifted)
         └── lint             (pre-commit gate on PRs)
```

### How Sync Works

1. **Push to main** — the `sync-on-push` workflow detects which files changed
2. **Lint gate** — pre-commit hooks must pass before sync proceeds
3. **Resolve affected repos** — the config parser determines which downstream repos map to those files
4. **Matrix fan-out** — each affected repo is synced in parallel (max 4 concurrent)
5. **rsync + PR** — files are copied to a branch in the downstream repo, and a PR is opened
6. **Daily drift detection** — a scheduled workflow compares all mapped files across all downstream repos, catching manual edits or missed syncs

```text
push to main ──▶ LINT ──▶ DETECT ──▶ SYNC ──▶ downstream repos
                  │        │          │
                  │        │          ├──▶ repo-1 (clone, rsync, PR)
                  │        │          ├──▶ repo-2 (clone, rsync, PR)
                  │        │          └──▶ repo-N (max 4 parallel)
                  │        │
                  │        └── which files changed? which repos affected?
                  │
                  └── fails? stop. no sync.

daily 06:00 UTC ──▶ DRIFT DETECTION ──▶ full compare all repos ──▶ PRs if drifted
```

### Content Organization

All content directories are **flat** — there are no per-repo subdirectories. Filtering is handled entirely by `sync-config/sync-config.yaml` using profiles, includes, and excludes.

## Setup

### 1. Create a GitHub PAT

Create a [Personal Access Token](https://github.com/settings/tokens) (or GitHub App token) with these scopes:
- `repo` — read/write access to downstream repos
- `workflow` — required if syncing workflow files

### 2. Add the secret

Add the token as a repository secret named `SYNC_PAT`:

```
Settings → Secrets and variables → Actions → New repository secret
Name: SYNC_PAT
Value: <your-token>
```

### 3. Configure downstream repos

Edit `sync-config/sync-config.yaml` to replace the placeholder repo names with your actual downstream repos:

```yaml
profiles:
  standard:
    repos:
      - your-org/ai-iac-module-template
      - your-org/ai-iac-consumer-template
    mappings:
      - source: agents/
        dest: .claude/agents/
      # ...
```

### 4. Test with a dry run

Trigger the sync manually to verify configuration:

```
Actions → Sync on Push → Run workflow → dry_run: true
```

## Sync Config

The `sync-config/sync-config.yaml` file controls all sync behavior. See [`sync-config/README.md`](sync-config/README.md) for the full schema.

### Profiles

Profiles group repos that share the same sync mappings:

```yaml
profiles:
  standard:         # Full sync: agents, skills, scripts, templates
    repos: [...]
  limited:          # Agents and skills only
    repos: [...]
  persona:          # Custom subset with different paths
    repos: [...]
```

### Standalone Repos

For repos that don't fit any profile:

```yaml
standalone:
  your-org/special-repo:
    mappings:
      - source: agents/
        dest: .github/claude/agents/
```

### Excludes and Includes

```yaml
global_excludes:          # Applied to all syncs
  - ".DS_Store"
  - "**/README.md"        # Per-directory READMEs stay in hub

profiles:
  persona:
    mappings:
      - source: skills/
        dest: .claude/skills/
        excludes:
          - "skills/terraform-plan/**"   # Skip specific skills
```

## Workflows

### Sync on Push

Triggers automatically when files change in `agents/`, `skills/`, `scripts/`, `templates/`, or `sync-config/` on the `main` branch. Also supports manual dispatch with options:

| Input | Description |
|-------|-------------|
| `force_full_sync` | Sync all mapped files to all repos (ignores change detection) |
| `dry_run` | Detect changes but don't create PRs |

### Drift Detection

Runs daily at 06:00 UTC. Compares all mapped files across all downstream repos and opens PRs for any drift. Also supports manual dispatch with `dry_run`.

## Adding Content

### New Agent

```bash
# Create the agent file
echo "Your agent definition here" > agents/my-agent.md

# Push to main — sync handles the rest
git add agents/my-agent.md && git commit -m "Add my-agent" && git push
```

### New Skill

```bash
mkdir skills/my-skill
echo "Your skill definition here" > skills/my-skill/SKILL.md

git add skills/my-skill/ && git commit -m "Add my-skill" && git push
```

### New Script

```bash
cat > scripts/my-script.sh << 'EOF'
#!/usr/bin/env bash
# Usage: my-script.sh [args]
# Description of what this does
set -euo pipefail
echo "Hello"
EOF
chmod +x scripts/my-script.sh

git add scripts/my-script.sh && git commit -m "Add my-script" && git push
```

## Edge Cases

| Scenario | Solution |
|----------|----------|
| Downstream repo missing target dir | `mkdir -p` before copy |
| Existing open sync PR | Force-push to same branch, update existing PR |
| File deleted in hub | `rsync --delete` removes it downstream (configurable via `sync_deletions`) |
| Sync config YAML error | `parse_config.py` fails with clear error |
| New repo in config doesn't exist | Checkout fails gracefully, other repos still sync |
| Sync config itself changes | Both workflows are triggered, ensuring all repos get the updated mappings |

## Local Development

### Pre-commit Hooks

This repo uses [pre-commit](https://pre-commit.com/) for automated validation. Install once:

```bash
pip install pre-commit
pre-commit install
```

Hooks run automatically on `git commit`. To run manually:

```bash
# Run all hooks on all files
pre-commit run --all-files

# Run a specific hook
pre-commit run validate-skills --all-files
pre-commit run validate-agents --all-files
```

### Authoring Guides

See `reference/` for comprehensive authoring guides:
- [`reference/skills-authoring-guide.md`](reference/skills-authoring-guide.md) — SKILL.md spec and conventions
- [`reference/agent-authoring-guide.md`](reference/agent-authoring-guide.md) — agent .md conventions

### Testing Sync Config

```bash
# Validate sync config syntax
python3 -c "import yaml; yaml.safe_load(open('sync-config/sync-config.yaml'))"

# Test config parser for a specific repo
CONFIG_PATH=sync-config/sync-config.yaml \
DOWNSTREAM_REPO=your-org/downstream-repo-1 \
CHANGED_FILES='["agents/plan-reviewer.md"]' \
SYNC_MODE=incremental \
python3 .github/actions/sync-files/parse_config.py
```
