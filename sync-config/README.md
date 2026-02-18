# Sync Configuration

Central mapping configuration that controls how files are synced from this hub to downstream repos.

## Schema

```yaml
version: "1"

defaults:
  target_branch: main # Branch to PR against in downstream repos
  pr_labels: [hub-sync] # Labels applied to sync PRs
  branch_prefix: hub-sync/ # Prefix for sync branches
  commit_prefix: "chore(sync):" # Prefix for commit messages
  sync_deletions: true # Remove files deleted in hub from downstream
  update_existing_pr: true # Force-push to existing sync PR branch

global_excludes: # Patterns excluded from all syncs
  - ".DS_Store"
  - ".gitkeep"
  - "**/README.md" # Per-directory READMEs stay in hub only

profiles:
  <profile-name>:
    host: github.com # GitHub host (default: github.com)
    repos:
      - org/repo-name
    mappings:
      - source: agents/ # Hub path
        dest: .claude/agents/ # Downstream path
        excludes: [] # Per-mapping excludes (source-relative or repo-root)
        includes: [] # Per-mapping includes (source-relative or repo-root; overrides excludes)

standalone:
  org/special-repo:
    host: github.com # GitHub host (default: github.com)
    mappings:
      - source: agents/
        dest: custom/path/
```

## Key Concepts

- **Profiles** group repos that share identical sync mappings
- **Standalone** repos have custom mappings that don't fit any profile
- **host** sets the GitHub instance for all repos in a profile or standalone entry (default: `github.com`). Use for GitHub Enterprise.
- **Excludes/Includes** at the mapping level override global settings
- **sync_deletions** controls whether files deleted in hub are also deleted downstream
