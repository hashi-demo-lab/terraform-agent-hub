---
# =============================================================================
# SKILL DEFINITION TEMPLATE
# =============================================================================
# Place in: .claude/skills/{skill-name}/SKILL.md
#
# A skill is a KNOWLEDGE PACKAGE loaded into an agent's context — not an
# autonomous executor. Unlike agents (which have models, tools, and run
# independently), skills provide domain expertise, decision frameworks,
# patterns, and procedural guidance that agents consume.
#
# Directory Structure:
#   skill-name/
#   ├── SKILL.md           (required — this file)
#   ├── scripts/           (optional — executable code agents can run)
#   ├── references/        (optional — documentation loaded on demand)
#   └── assets/            (optional — templates, schemas, static resources)
#
# YAML Frontmatter Rules (AgentSkills.io spec):
#   - name: REQUIRED. Max 64 chars. Lowercase letters, numbers, hyphens only.
#           Must not start/end with hyphen. No consecutive hyphens (--).
#           Must match the parent directory name.
#   - description: REQUIRED. Max 1024 chars. Describes WHAT it does + WHEN to
#                  use it. Include trigger keywords that help agents identify
#                  relevant tasks.
#   - license: optional. License name or reference to bundled LICENSE file.
#   - compatibility: optional. Max 500 chars. Environment requirements
#                    (products, system packages, network access).
#   - metadata: optional. Arbitrary key-value pairs (author, version, etc.).
#   - allowed-tools: optional. Space-delimited pre-approved tools.
#
# Progressive Disclosure (3 levels):
#   1. Metadata (~100 tokens): name + description — always loaded at startup
#   2. Instructions (<5000 tokens): SKILL.md body — loaded on activation
#   3. Resources (as needed): scripts/, references/, assets/ — loaded on demand
#
# Key Principles:
#   - "The context window is a public good" — only include what the model
#     doesn't already know. Challenge each line: does this justify its tokens?
#   - Keep SKILL.md under 500 lines. Move detailed content to references/.
#   - Prefer concise examples over verbose explanations.
#   - Use imperative/infinitive form throughout.
#
# Degrees of Freedom — match specificity to task fragility:
#   - HIGH (text instructions): multiple valid approaches, context-dependent
#   - MEDIUM (pseudocode/patterns): preferred approach exists, some variation OK
#   - LOW (exact scripts): fragile operations, consistency critical
#
# Skill vs Agent — when to use which:
#   - Skill: reusable knowledge consumed by multiple agents (patterns, guides,
#            decision frameworks, domain rules, reference material)
#   - Agent: autonomous executor with its own model, tools, and workflow
#
# Body Structure:
#   There are NO required sections — structure the body as whatever helps
#   agents perform the task effectively. Common patterns include:
#     - Knowledge skills: Principles → Patterns → Examples → Edge Cases
#     - Procedural skills: Steps → Decision Points → Examples
#     - Reference skills: Lookup Tables → Rules → Exceptions
#   Pick the structure that fits the domain. See examples below.
# =============================================================================

name: skill-name
description: |
  [One sentence: WHAT this skill provides — the knowledge or capability].
  [One sentence: WHEN to use it — trigger conditions and keywords].
---

# Skill Title

[1-2 sentence summary of what knowledge this skill provides and why it matters.
Only include information the model doesn't already possess.]

<!--
============================================================================
CHOOSE A BODY STRUCTURE that fits your skill type. Delete the others.
The sections below are EXAMPLES of common patterns — not required sections.
============================================================================
-->


<!-- =====================================================================
     PATTERN A: Knowledge / Domain Expertise Skill
     Use for: style guides, architecture patterns, security baselines,
              domain rules, coding conventions
     Examples: terraform-style-guide, tf-implementation-patterns,
               tf-security-baselines, brand-guidelines
     ===================================================================== -->

## Core Principles

<!--
The foundational rules that govern decisions in this domain.
Keep to 3-7 principles. Each should be actionable, not aspirational.
-->

- **[Principle Name]**: [Concise rule — what to do and why]
- **[Principle Name]**: [Concise rule — what to do and why]
- **[Principle Name]**: [Concise rule — what to do and why]

## Patterns

<!--
Concrete, reusable patterns the agent should apply. Examples are the most
token-efficient way to convey these — show don't tell.
-->

### [Pattern Name]

```
[Example of correct pattern usage]
```

### [Anti-Pattern Name]

```
[Example of what to avoid — with brief explanation of WHY]
```

## Edge Cases

<!--
Non-obvious situations where the default rules don't apply or need nuance.
Only include cases the model would get wrong without guidance.
-->

- **[Scenario]**: [What to do differently and why]


<!-- =====================================================================
     PATTERN B: Procedural / How-To Skill
     Use for: step-by-step guides, creation processes, operational runbooks
     Examples: skill-creator, mcp-builder, webapp-testing
     ===================================================================== -->

## Process

<!--
Sequential steps. Use numbered lists for strict ordering.
Annotate decision points where the agent must choose between approaches.
-->

### Step 1 — [Name]

[What to do. Include decision criteria if there are branches.]

### Step 2 — [Name]

[What to do. Reference scripts/ if deterministic execution is needed.]

### Step 3 — [Name]

[What to do. Include validation/verification criteria.]

## Decision Framework

<!--
For skills where the agent must choose between approaches based on context.
Use a decision tree, table, or if/then structure.
-->

| Condition | Approach | Rationale |
|-----------|----------|-----------|
| [When X]  | [Do A]   | [Why]     |
| [When Y]  | [Do B]   | [Why]     |

## Critical Guidance

<!--
Hard-won lessons and non-obvious gotchas. Format as DO/DON'T pairs.
Only include what the model would get wrong without this guidance.
-->

- DO: [Correct approach]
- DON'T: [Common mistake — why it fails]


<!-- =====================================================================
     PATTERN C: Reference / Lookup Skill
     Use for: taxonomies, checklists, evaluation criteria, scoring rubrics
     Examples: tf-domain-taxonomy, tf-judge-criteria, tf-checklist-patterns
     ===================================================================== -->

## Categories

### [Category 1]

| Item | Description | Notes |
|------|-------------|-------|
| ...  | ...         | ...   |

### [Category 2]

| Item | Description | Notes |
|------|-------------|-------|
| ...  | ...         | ...   |

## Rules

<!--
Hard rules that govern how to apply the reference material.
-->

- [Rule 1]
- [Rule 2]

## Exceptions

- **[Exception scenario]**: [What to do instead]


<!-- =====================================================================
     COMMON OPTIONAL SECTIONS (use with any pattern above)
     ===================================================================== -->

## Examples

<!--
Concrete input/output pairs. The most token-efficient teaching tool.
Include edge cases where behavior isn't obvious.
-->

**Good**:
```
[Example of correct usage or output]
```

**Bad**:
```
[Example of incorrect usage — explain WHY it's wrong]
```

## Bundled Resources

<!--
OPTIONAL: Only include if the skill ships with additional files.
Use relative paths from SKILL.md. Keep one level deep.

File types and when to use them:
  - scripts/    → Deterministic code the agent runs. Use when operations are
                   fragile or code would be repeatedly rewritten.
  - references/ → Documentation loaded as context on demand. For large files
                   (>10k words), include grep patterns for findability.
  - assets/     → Static files used in output (templates, schemas, fonts).
                   NOT loaded as context — copied into generated output.
-->

- [Script description](scripts/script-name.py) — [when to run it]
- [Reference guide](references/REFERENCE.md) — [what it covers]
- [Template file](assets/template.ext) — [what it's used for]
