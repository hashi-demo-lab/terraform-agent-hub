# Templates

Shared Terraform templates and configuration files synced to downstream repos.

## Conventions

- Templates can be any file type (`.tf`, `.tfvars`, `.hcl`, `.tpl`, etc.)
- Use descriptive filenames that indicate purpose (e.g., `backend.tf`, `provider-azurerm.tf`)
- Templates are synced to their configured destination in downstream repos
- Avoid hardcoding values — use variables or placeholders that downstream repos can override

## Adding a New Template

1. Create `templates/<template-name>.<ext>`
2. Update `sync-config/sync-config.yaml` to configure the destination path
3. Push to `main` — the sync workflow handles distribution
