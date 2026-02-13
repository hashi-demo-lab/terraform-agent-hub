#!/usr/bin/env python3
"""
Pre-commit hook: validate agent .md files under agents/.

Checks each .md file (excluding README.md) for:
  - Non-empty content
  - Kebab-case filename

Exit codes:
  0 — all checks passed
  1 — one or more errors found

Output uses ::error:: annotations for GitHub Actions compatibility.
"""

import re
import sys
from pathlib import Path

AGENTS_DIR = Path("agents")
FILENAME_PATTERN = re.compile(r"^[a-z][a-z0-9-]+\.md$")
SKIP_FILES = {"README.md"}


def validate_agent(agent_file: Path) -> list[str]:
    """Validate a single agent .md file. Returns list of errors."""
    errors: list[str] = []

    # Skip non-agent files
    if agent_file.name in SKIP_FILES:
        return errors

    # Filename must be kebab-case
    if not FILENAME_PATTERN.match(agent_file.name):
        errors.append(
            f"{agent_file}: filename '{agent_file.name}' is not valid kebab-case "
            f"(expected pattern: {FILENAME_PATTERN.pattern})"
        )

    # File must be non-empty
    content = agent_file.read_text(encoding="utf-8")
    if not content.strip():
        errors.append(f"{agent_file}: agent file is empty")

    return errors


def main() -> int:
    """Validate agent files. Can also accept file paths as arguments."""
    all_errors: list[str] = []

    # Determine which agent files to check
    if len(sys.argv) > 1:
        # Pre-commit passes changed file paths as arguments
        agent_files = [
            Path(arg) for arg in sys.argv[1:]
            if arg.startswith("agents/") and arg.endswith(".md")
        ]
        if not agent_files:
            return 0
    elif AGENTS_DIR.is_dir():
        agent_files = sorted(AGENTS_DIR.glob("*.md"))
    else:
        return 0

    for agent_file in agent_files:
        all_errors.extend(validate_agent(agent_file))

    for error in all_errors:
        print(f"::error::{error}", file=sys.stderr)

    if all_errors:
        print(
            f"\nAgent validation failed: {len(all_errors)} error(s)",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
