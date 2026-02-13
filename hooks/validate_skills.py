#!/usr/bin/env python3
"""
Pre-commit hook: validate SKILL.md files under skills/.

Checks each skill subdirectory for compliance with:
  - Anthropic's "Complete Guide to Building Skills for Claude" (Jan 2026)
  - Hub-specific conventions (500-line limit, forbidden files)

Rules:
  - SKILL.md exists and is non-empty
  - SKILL.md is under 500 lines (hub policy; Anthropic recommends < 5000 words)
  - Valid YAML frontmatter with required fields
  - Kebab-case name, no reserved words ("claude", "anthropic")
  - Description present, under 1024 chars, no XML angle brackets
  - No hardcoded absolute paths in body
  - No forbidden files (README.md, CHANGELOG.md, etc.)
  - references/ directory is flat (no nested subdirs)

Exit codes:
  0 — all checks passed
  1 — one or more errors found

Output uses ::error:: and ::warning:: annotations for GitHub Actions compatibility.
"""

import re
import sys
from pathlib import Path

import yaml

SKILLS_DIR = Path("skills")
MAX_LINES = 500  # Hub policy (Anthropic spec recommends < 5000 words)
MAX_NAME_LENGTH = 64
MAX_DESCRIPTION_LENGTH = 1024  # Per Anthropic spec
NAME_PATTERN = re.compile(r"^[a-z][a-z0-9]*(-[a-z0-9]+)*$")
RESERVED_NAME_WORDS = {"claude", "anthropic"}  # Per Anthropic spec
HARDCODED_PATH_PATTERN = re.compile(r"(/Users/|/home/|C:\\|D:\\)", re.IGNORECASE)
FORBIDDEN_FILES = {
    "README.md",
    "CHANGELOG.md",
    "INSTALLATION_GUIDE.md",
    "QUICK_REFERENCE.md",
}


def parse_frontmatter(content: str) -> tuple[dict | None, str]:
    """Extract YAML frontmatter and body from SKILL.md content."""
    if not content.startswith("---"):
        return None, content

    parts = content.split("---", 2)
    if len(parts) < 3:
        return None, content

    try:
        fm = yaml.safe_load(parts[1])
    except yaml.YAMLError:
        return None, content

    if not isinstance(fm, dict):
        return None, content

    return fm, parts[2]


def validate_skill(skill_dir: Path) -> tuple[list[str], list[str]]:
    """Validate a single skill directory. Returns (errors, warnings)."""
    errors: list[str] = []
    warnings: list[str] = []
    skill_md = skill_dir / "SKILL.md"

    # SKILL.md must exist
    if not skill_md.exists():
        errors.append(f"{skill_dir}: SKILL.md is missing")
        return errors, warnings

    content = skill_md.read_text(encoding="utf-8")

    # SKILL.md must be non-empty
    if not content.strip():
        errors.append(f"{skill_md}: SKILL.md is empty")
        return errors, warnings

    # SKILL.md must be under 500 lines
    line_count = len(content.splitlines())
    if line_count >= MAX_LINES:
        errors.append(f"{skill_md}: SKILL.md is {line_count} lines (max {MAX_LINES})")

    # Valid YAML frontmatter
    frontmatter, body = parse_frontmatter(content)
    if frontmatter is None:
        errors.append(f"{skill_md}: missing or invalid YAML frontmatter")
    else:
        # name field: required, kebab-case, max 64 chars
        name = frontmatter.get("name")
        if not name:
            errors.append(f"{skill_md}: frontmatter missing required 'name' field")
        elif not isinstance(name, str):
            errors.append(
                f"{skill_md}: 'name' must be a string, got {type(name).__name__}"
            )
        else:
            if len(name) > MAX_NAME_LENGTH:
                errors.append(
                    f"{skill_md}: name '{name}' exceeds {MAX_NAME_LENGTH} chars"
                )
            if not NAME_PATTERN.match(name):
                errors.append(
                    f"{skill_md}: name '{name}' is not valid kebab-case "
                    f"(expected pattern: {NAME_PATTERN.pattern})"
                )
            # Reserved words check (per Anthropic spec)
            for word in RESERVED_NAME_WORDS:
                if word in name.lower():
                    errors.append(
                        f"{skill_md}: name '{name}' contains reserved word '{word}'"
                    )

        # description field: required, non-empty, under 1024 chars, no XML tags
        description = frontmatter.get("description")
        if not description:
            errors.append(
                f"{skill_md}: frontmatter missing required 'description' field"
            )
        elif not isinstance(description, str):
            errors.append(
                f"{skill_md}: 'description' must be a string, got {type(description).__name__}"
            )
        else:
            if len(description) > MAX_DESCRIPTION_LENGTH:
                errors.append(
                    f"{skill_md}: description is {len(description)} chars "
                    f"(max {MAX_DESCRIPTION_LENGTH})"
                )
            if "<" in description or ">" in description:
                errors.append(
                    f"{skill_md}: description contains XML angle brackets "
                    f"(< >) which are forbidden in frontmatter"
                )

    # No hardcoded absolute paths in body
    for i, line in enumerate(body.splitlines(), start=1):
        if HARDCODED_PATH_PATTERN.search(line):
            errors.append(
                f"{skill_md}:{i}: hardcoded absolute path detected — use relative paths"
            )

    # No forbidden files in skill directory
    for child in skill_dir.iterdir():
        if child.name in FORBIDDEN_FILES:
            errors.append(f"{child}: forbidden file in skill directory (remove it)")

    # references/ must be flat (no nested subdirectories)
    refs_dir = skill_dir / "references"
    if refs_dir.is_dir():
        for item in refs_dir.iterdir():
            if item.is_dir():
                warnings.append(
                    f"{item}: nested subdirectory in references/ — keep references flat"
                )

    return errors, warnings


def main() -> int:
    """Validate all skill directories. Can also accept file paths as arguments."""
    all_errors: list[str] = []
    all_warnings: list[str] = []

    # Determine which skill directories to check
    if len(sys.argv) > 1:
        # Pre-commit passes changed file paths as arguments
        skill_dirs: set[Path] = set()
        for arg in sys.argv[1:]:
            path = Path(arg)
            # Walk up to find the skill directory (immediate child of skills/)
            parts = path.parts
            if len(parts) >= 3 and parts[0] == "skills":
                skill_dir = SKILLS_DIR / parts[1]
                if skill_dir.is_dir():
                    skill_dirs.add(skill_dir)
        if not skill_dirs:
            return 0
    elif SKILLS_DIR.is_dir():
        skill_dirs = {
            d for d in SKILLS_DIR.iterdir() if d.is_dir() and not d.name.startswith(".")
        }
    else:
        return 0

    for skill_dir in sorted(skill_dirs):
        errors, warnings = validate_skill(skill_dir)
        all_errors.extend(errors)
        all_warnings.extend(warnings)

    for warning in all_warnings:
        print(f"::warning::{warning}", file=sys.stderr)

    for error in all_errors:
        print(f"::error::{error}", file=sys.stderr)

    if all_errors:
        print(
            f"\nSkill validation failed: {len(all_errors)} error(s), "
            f"{len(all_warnings)} warning(s)",
            file=sys.stderr,
        )
        return 1

    if all_warnings:
        print(
            f"\nSkill validation passed with {len(all_warnings)} warning(s)",
            file=sys.stderr,
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
