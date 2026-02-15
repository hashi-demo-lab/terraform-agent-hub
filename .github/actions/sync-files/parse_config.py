#!/usr/bin/env python3
"""
Parse sync-config.yaml and resolve mappings for a given downstream repo.

Reads environment variables:
  CONFIG_PATH       - path to sync-config.yaml
  DOWNSTREAM_REPO   - target repo (org/name)
  CHANGED_FILES     - JSON array of changed file paths
  SYNC_MODE         - 'incremental' or 'full'

Outputs a JSON object to stdout:
{
  "defaults": { ... },
  "mappings": [
    {
      "source": "agents/",
      "dest": ".claude/agents/",
      "excludes": [...],
      "includes": [...]
    }
  ],
  "global_excludes": [...]
}
"""

import json
import os
import sys

import yaml


def load_config(config_path: str) -> dict:
    """Load and validate the sync config YAML."""
    try:
        with open(config_path) as f:
            config = yaml.safe_load(f)
    except FileNotFoundError:
        print(f"::error::Config file not found: {config_path}", file=sys.stderr)
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"::error::Invalid YAML in {config_path}: {e}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(config, dict):
        print(
            f"::error::Config must be a YAML mapping, got {type(config).__name__}",
            file=sys.stderr,
        )
        sys.exit(1)

    version = config.get("version")
    if version != "1":
        print(
            f"::error::Unsupported config version: {version} (expected '1')",
            file=sys.stderr,
        )
        sys.exit(1)

    return config


def find_repo_mappings(config: dict, downstream_repo: str) -> list[dict] | None:
    """Find mappings for the given downstream repo from all matching profiles and standalone."""
    all_mappings: list[dict] = []
    seen: set[tuple[str, str]] = set()

    # Collect from all matching profiles
    profiles = config.get("profiles", {}) or {}
    for profile_name, profile in profiles.items():
        if not profile:
            continue
        repos = profile.get("repos", [])
        if downstream_repo in repos:
            for m in profile.get("mappings", []):
                key = (m["source"], m["dest"])
                if key not in seen:
                    seen.add(key)
                    all_mappings.append(m)

    # Collect from standalone
    standalone = config.get("standalone", {}) or {}
    if downstream_repo in standalone and standalone[downstream_repo]:
        for m in standalone[downstream_repo].get("mappings", []):
            key = (m["source"], m["dest"])
            if key not in seen:
                seen.add(key)
                all_mappings.append(m)

    return all_mappings if all_mappings else None


def filter_mappings_by_changed_files(
    mappings: list[dict], changed_files: list[str]
) -> list[dict]:
    """In incremental mode, only return mappings whose source dirs contain changes."""
    if not changed_files:
        return mappings

    filtered = []
    for mapping in mappings:
        source = mapping["source"]
        # Check if any changed file falls under this source directory
        for changed_file in changed_files:
            if changed_file.startswith(source) or changed_file == source.rstrip("/"):
                filtered.append(mapping)
                break

    return filtered


def resolve_mappings(
    config: dict,
    downstream_repo: str,
    changed_files: list[str],
    sync_mode: str,
) -> dict:
    """Resolve the full mapping configuration for a downstream repo."""
    defaults = config.get("defaults", {})
    global_excludes = config.get("global_excludes", [])

    mappings = find_repo_mappings(config, downstream_repo)
    if mappings is None:
        print(
            f"::error::Repo '{downstream_repo}' not found in any profile or standalone config",
            file=sys.stderr,
        )
        sys.exit(1)

    # In incremental mode, filter to only affected mappings
    if sync_mode == "incremental" and changed_files:
        mappings = filter_mappings_by_changed_files(mappings, changed_files)

    # Normalize mapping structure
    resolved = []
    for m in mappings:
        resolved.append(
            {
                "source": m["source"],
                "dest": m["dest"],
                "excludes": m.get("excludes", []),
                "includes": m.get("includes", []),
            }
        )

    return {
        "defaults": defaults,
        "mappings": resolved,
        "global_excludes": global_excludes,
    }


def main():
    config_path = os.environ.get("CONFIG_PATH", "sync-config/sync-config.yaml")
    downstream_repo = os.environ.get("DOWNSTREAM_REPO", "")
    changed_files_json = os.environ.get("CHANGED_FILES", "[]")
    sync_mode = os.environ.get("SYNC_MODE", "incremental")

    if not downstream_repo:
        print(
            "::error::DOWNSTREAM_REPO environment variable is required", file=sys.stderr
        )
        sys.exit(1)

    try:
        changed_files = json.loads(changed_files_json)
    except json.JSONDecodeError as e:
        print(f"::error::Invalid CHANGED_FILES JSON: {e}", file=sys.stderr)
        sys.exit(1)

    config = load_config(config_path)
    result = resolve_mappings(config, downstream_repo, changed_files, sync_mode)
    print(json.dumps(result, separators=(",", ":")))


if __name__ == "__main__":
    main()
