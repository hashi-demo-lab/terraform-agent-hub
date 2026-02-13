# Sync Configuration

Central mapping configuration that controls how files are synced from this hub to downstream repos.

## Schema

```yaml
version: "1"

defaults:
  target_branch: main           # Branch to PR against in downstream repos
  pr_labels: [hub-sync]         # Labels applied to sync PRs
  branch_prefix: hub-sync/      # Prefix for sync branches
  commit_prefix: "chore(sync):" # Prefix for commit messages
  sync_deletions: true          # Remove files deleted in hub from downstream
  update_existing_pr: true      # Force-push to existing sync PR branch

global_excludes:                # Patterns excluded from all syncs
  - ".DS_Store"
  - ".gitkeep"
  - "**/README.md"              # Per-directory READMEs stay in hub only

profiles:
  <profile-name>:
    repos:
      - org/repo-name
    mappings:
      - source: agents/         # Hub path
        dest: .claude/agents/   # Downstream path
        excludes: []            # Per-mapping excludes
        includes: []            # Per-mapping includes (overrides excludes)

standalone:
  org/special-repo:
    mappings:
      - source: agents/
        dest: custom/path/
```

## Key Concepts

- **Profiles** group repos that share identical sync mappings
- **Standalone** repos have custom mappings that don't fit any profile
- **Excludes/Includes** at the mapping level override global settings
- **sync_deletions** controls whether files deleted in hub are also deleted downstream
