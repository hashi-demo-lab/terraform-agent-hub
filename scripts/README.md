# Scripts

Shared shell scripts synced to downstream repos.

## Conventions

- Scripts should be POSIX-compatible where possible (`#!/usr/bin/env bash`)
- Filename should describe the action (e.g., `validate-terraform.sh`)
- Scripts are synced to `scripts/` in downstream repos by default
- Include a usage comment block at the top of each script
- Scripts must be executable (`chmod +x`)

## Adding a New Script

1. Create `scripts/<script-name>.sh`
2. Add a usage comment block at the top
3. Make it executable: `chmod +x scripts/<script-name>.sh`
4. Update `sync-config/sync-config.yaml` if the script should be excluded from specific profiles
5. Push to `main` — the sync workflow handles distribution
