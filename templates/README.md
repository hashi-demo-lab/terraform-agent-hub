# Templates

Markdown artifact templates synced to downstream repos. These are scaffolds for generating structured documents (plans, specs, reports, task lists, etc.) during development workflows.

## Conventions

- One `.md` file per template with a descriptive filename (e.g., `plan-template.md`, `spec-template.md`)
- Templates are synced to their configured destination in downstream repos
- Use the standard placeholder convention declared at the top of each file:
  - `[BRACKETS]` — human-authored content (instructions, descriptions)
  - `{{DOUBLE_BRACES}}` — machine-filled values (timestamps, scores, IDs)
- Avoid embedding concrete sample data in tables — use placeholders instead
- Avoid hardcoded absolute paths — use relative paths or placeholders

## Adding a New Template

1. Create `templates/<template-name>.md`
2. Add the placeholder convention comment at the top of the file
3. Update `sync-config/sync-config.yaml` to configure the destination path if needed
4. Push to `main` — the sync workflow handles distribution
