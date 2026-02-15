#!/usr/bin/env bash
# shellcheck disable=SC2129
set -euo pipefail

# ──────────────────────────────────────────────
# sync.sh — Core sync logic for terraform-agent-hub
#
# Checks out a downstream repo, copies mapped files from the hub,
# detects changes, and creates/updates a PR.
#
# Required environment variables:
#   DOWNSTREAM_REPO  - target repo (org/name)
#   TOKEN            - GitHub PAT or App token
#   HUB_SHA          - hub commit SHA that triggered sync
#   MAPPINGS_JSON    - JSON output from parse_config.py
#   DRY_RUN          - "true" to skip PR creation
# ──────────────────────────────────────────────

# ── Authenticate gh CLI with the sync token ──
export GH_TOKEN="$TOKEN"

# ── Parse config from JSON ──────────────────
DEFAULTS=$(echo "$MAPPINGS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d['defaults']))")
MAPPINGS=$(echo "$MAPPINGS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d['mappings']))")
GLOBAL_EXCLUDES=$(echo "$MAPPINGS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d['global_excludes']))")

TARGET_BRANCH=$(echo "$DEFAULTS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('target_branch','main'))")
BRANCH_PREFIX=$(echo "$DEFAULTS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('branch_prefix','hub-sync/'))")
COMMIT_PREFIX=$(echo "$DEFAULTS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('commit_prefix','chore(sync):'))")
PR_LABELS=$(echo "$DEFAULTS" | python3 -c "import sys,json; print(','.join(json.load(sys.stdin).get('pr_labels',['hub-sync'])))")
SYNC_DELETIONS=$(echo "$DEFAULTS" | python3 -c "import sys,json; print(str(json.load(sys.stdin).get('sync_deletions',True)).lower())")
UPDATE_EXISTING_PR=$(echo "$DEFAULTS" | python3 -c "import sys,json; print(str(json.load(sys.stdin).get('update_existing_pr',True)).lower())")

MAPPING_COUNT=$(echo "$MAPPINGS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

if [[ "$MAPPING_COUNT" -eq 0 ]]; then
  echo "::notice::No mappings to sync for $DOWNSTREAM_REPO"
  echo "changes_detected=false" >> "$GITHUB_OUTPUT"
  echo "files_synced=0" >> "$GITHUB_OUTPUT"
  echo "pr_url=" >> "$GITHUB_OUTPUT"
  exit 0
fi

SHORT_SHA="${HUB_SHA:0:7}"
SYNC_BRANCH="${BRANCH_PREFIX}${SHORT_SHA}"
WORK_DIR=$(mktemp -d)
FILES_SYNCED=0

echo "::group::Sync config for $DOWNSTREAM_REPO"
echo "  Target branch: $TARGET_BRANCH"
echo "  Sync branch:   $SYNC_BRANCH"
echo "  Mappings:      $MAPPING_COUNT"
echo "  Sync deletions: $SYNC_DELETIONS"
echo "::endgroup::"

# ── Clone downstream repo ──────────────────
echo "::group::Cloning $DOWNSTREAM_REPO"
if ! git clone --depth 1 --branch "$TARGET_BRANCH" \
  "https://x-access-token:${TOKEN}@github.com/${DOWNSTREAM_REPO}.git" \
  "$WORK_DIR/downstream" 2>&1; then
  echo "::error::Failed to clone $DOWNSTREAM_REPO — does the repo exist and does the token have access?"
  echo "changes_detected=false" >> "$GITHUB_OUTPUT"
  echo "files_synced=0" >> "$GITHUB_OUTPUT"
  echo "pr_url=" >> "$GITHUB_OUTPUT"
  exit 0
fi
echo "::endgroup::"

cd "$WORK_DIR/downstream"
git checkout -b "$SYNC_BRANCH" 2>/dev/null || git checkout "$SYNC_BRANCH"

# ── Build rsync exclude args from global excludes ──
GLOBAL_EXCLUDE_ARGS=""
EXCLUDE_COUNT=$(echo "$GLOBAL_EXCLUDES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
for i in $(seq 0 $((EXCLUDE_COUNT - 1))); do
  PATTERN=$(echo "$GLOBAL_EXCLUDES" | python3 -c "import sys,json; print(json.load(sys.stdin)[$i])")
  GLOBAL_EXCLUDE_ARGS="$GLOBAL_EXCLUDE_ARGS --exclude=$PATTERN"
done

# ── Sync each mapping ──────────────────────
for i in $(seq 0 $((MAPPING_COUNT - 1))); do
  SOURCE=$(echo "$MAPPINGS" | python3 -c "import sys,json; print(json.load(sys.stdin)[$i]['source'])")
  DEST=$(echo "$MAPPINGS" | python3 -c "import sys,json; print(json.load(sys.stdin)[$i]['dest'])")
  EXCLUDES=$(echo "$MAPPINGS" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)[$i].get('excludes',[])))")
  INCLUDES=$(echo "$MAPPINGS" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)[$i].get('includes',[])))")

  HUB_SOURCE="${GITHUB_WORKSPACE}/${SOURCE}"
  DOWNSTREAM_DEST="${WORK_DIR}/downstream/${DEST}"

  echo "::group::Mapping: ${SOURCE} → ${DEST}"

  if [[ ! -d "$HUB_SOURCE" ]]; then
    echo "::warning::Source directory not found: ${SOURCE} — skipping"
    echo "::endgroup::"
    continue
  fi

  # Ensure destination exists
  mkdir -p "$DOWNSTREAM_DEST"

  # Build per-mapping exclude/include args
  MAPPING_ARGS=""

  EXCL_COUNT=$(echo "$EXCLUDES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
  for j in $(seq 0 $((EXCL_COUNT - 1))); do
    PATTERN=$(echo "$EXCLUDES" | python3 -c "import sys,json; print(json.load(sys.stdin)[$j])")
    MAPPING_ARGS="$MAPPING_ARGS --exclude=$PATTERN"
  done

  INCL_COUNT=$(echo "$INCLUDES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
  for j in $(seq 0 $((INCL_COUNT - 1))); do
    PATTERN=$(echo "$INCLUDES" | python3 -c "import sys,json; print(json.load(sys.stdin)[$j])")
    MAPPING_ARGS="$MAPPING_ARGS --include=$PATTERN"
  done

  # Build rsync command
  DELETE_ARG=""
  if [[ "$SYNC_DELETIONS" == "true" ]]; then
    DELETE_ARG="--delete"
  fi

  # shellcheck disable=SC2086
  rsync -av $DELETE_ARG \
    $GLOBAL_EXCLUDE_ARGS \
    $MAPPING_ARGS \
    "${HUB_SOURCE}" \
    "${DOWNSTREAM_DEST}"

  SYNCED=$(find "$DOWNSTREAM_DEST" -type f | wc -l | tr -d ' ')
  FILES_SYNCED=$((FILES_SYNCED + SYNCED))
  echo "  Files in destination: $SYNCED"
  echo "::endgroup::"
done

# ── Detect changes ─────────────────────────
git add -A
if git diff --cached --quiet; then
  echo "::notice::No changes detected for $DOWNSTREAM_REPO"
  echo "changes_detected=false" >> "$GITHUB_OUTPUT"
  echo "files_synced=$FILES_SYNCED" >> "$GITHUB_OUTPUT"
  echo "pr_url=" >> "$GITHUB_OUTPUT"
  rm -rf "$WORK_DIR"
  exit 0
fi

echo "changes_detected=true" >> "$GITHUB_OUTPUT"
echo "files_synced=$FILES_SYNCED" >> "$GITHUB_OUTPUT"

CHANGED_LIST=$(git diff --cached --name-only)
CHANGED_COUNT=$(echo "$CHANGED_LIST" | wc -l | tr -d ' ')

# Output changed file list (use delimiter for multiline)
{
  echo "changed_list<<CHANGED_LIST_EOF"
  echo "$CHANGED_LIST"
  echo "CHANGED_LIST_EOF"
} >> "$GITHUB_OUTPUT"
echo "::notice::Detected $CHANGED_COUNT changed files in $DOWNSTREAM_REPO"

# ── Dry run check ──────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
  echo "::notice::Dry run — skipping PR creation"
  echo "Changed files:"
  echo "$CHANGED_LIST"
  echo "pr_url=" >> "$GITHUB_OUTPUT"
  rm -rf "$WORK_DIR"
  exit 0
fi

# ── Commit and push ────────────────────────
COMMIT_MSG="${COMMIT_PREFIX} sync from hub (${SHORT_SHA})

Synced ${CHANGED_COUNT} file(s) from terraform-agent-hub.
Hub commit: ${HUB_SHA}

Changed files:
${CHANGED_LIST}"

git config user.name "hub-sync[bot]"
git config user.email "hub-sync[bot]@users.noreply.github.com"
git commit -m "$COMMIT_MSG"
git push --force "https://x-access-token:${TOKEN}@github.com/${DOWNSTREAM_REPO}.git" "$SYNC_BRANCH"

# ── Create or update PR ───────────────────
PR_TITLE="${COMMIT_PREFIX} sync from terraform-agent-hub (${SHORT_SHA})"
PR_BODY="## Hub Sync

Automated sync from [terraform-agent-hub](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}) commit [\`${SHORT_SHA}\`](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${HUB_SHA}).

### Changed files
\`\`\`
${CHANGED_LIST}
\`\`\`

---
*This PR was created automatically by the hub sync workflow.*"

# Check for existing PR
EXISTING_PR=$(gh pr list \
  --repo "$DOWNSTREAM_REPO" \
  --head "$SYNC_BRANCH" \
  --base "$TARGET_BRANCH" \
  --state open \
  --json url \
  --jq '.[0].url // empty' 2>/dev/null || echo "")

if [[ -n "$EXISTING_PR" && "$UPDATE_EXISTING_PR" == "true" ]]; then
  echo "::notice::Updated existing PR: $EXISTING_PR"
  echo "pr_url=$EXISTING_PR" >> "$GITHUB_OUTPUT"
else
  # Ensure labels exist in downstream repo
  IFS=',' read -ra LABEL_ARRAY <<< "$PR_LABELS"
  for label in "${LABEL_ARRAY[@]}"; do
    if ! gh label list --repo "$DOWNSTREAM_REPO" --search "$label" --json name --jq '.[].name' 2>/dev/null | grep -qx "$label"; then
      gh label create "$label" --repo "$DOWNSTREAM_REPO" --description "Automated sync from terraform-agent-hub" --color "1d76db" 2>/dev/null || true
    fi
  done

  # Create new PR
  LABEL_ARGS=""
  for label in "${LABEL_ARRAY[@]}"; do
    LABEL_ARGS="$LABEL_ARGS --label $label"
  done

  # shellcheck disable=SC2086
  NEW_PR=$(gh pr create \
    --repo "$DOWNSTREAM_REPO" \
    --head "$SYNC_BRANCH" \
    --base "$TARGET_BRANCH" \
    --title "$PR_TITLE" \
    --body "$PR_BODY" \
    $LABEL_ARGS 2>&1 || echo "")

  if [[ "$NEW_PR" == http* ]]; then
    echo "::notice::Created PR: $NEW_PR"
    echo "pr_url=$NEW_PR" >> "$GITHUB_OUTPUT"
  else
    echo "::warning::PR creation returned: $NEW_PR"
    echo "pr_url=" >> "$GITHUB_OUTPUT"
  fi
fi

# ── Cleanup ────────────────────────────────
rm -rf "$WORK_DIR"
echo "Sync complete for $DOWNSTREAM_REPO"
