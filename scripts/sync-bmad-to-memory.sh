#!/usr/bin/env bash
set -euo pipefail

# sync-bmad-to-memory.sh - Parse BMAD artifacts and store as Claude Flow memory patterns
#
# Usage:
#   scripts/sync-bmad-to-memory.sh              # Sync all BMAD artifacts
#   scripts/sync-bmad-to-memory.sh <file-path>  # Sync just that file (used by post-edit hook)

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BMAD_OUTPUT="$PROJECT_ROOT/_bmad-output"
CLI="npx @claude-flow/cli@latest"

# Store a pattern in Claude Flow memory (idempotent via same key)
store_pattern() {
  local key="$1"
  local value="$2"
  # Truncate value to avoid CLI arg length issues
  value="${value:0:200}"
  $CLI memory store --key "$key" --value "$value" --namespace patterns 2>/dev/null || true
}

# --- Extractors per artifact type ---

sync_architecture_decisions() {
  local file="$BMAD_OUTPUT/brainstorming/architecture-diagram.md"
  [ -f "$file" ] || return 0

  # Extract rows from the 33-decision table: "| N | Decision | Choice | Rationale |"
  local n=0
  # shellcheck disable=SC2034
  while IFS='|' read -r _ num decision choice rationale _; do
    num=$(echo "$num" | tr -d ' ')
    # Skip non-numeric rows (header, separator)
    [[ "$num" =~ ^[0-9]+$ ]] || continue
    decision=$(echo "$decision" | sed 's/^ *//;s/ *$//')
    choice=$(echo "$choice" | sed 's/^ *//;s/ *$//;s/\*\*//g')
    store_pattern "bmad:arch:$num" "$decision: $choice"
    n=$((n + 1))
  done < <(grep -E '^\| *[0-9]+ *\|' "$file")
  echo "  architecture decisions: $n"
}

sync_epics() {
  local file="$BMAD_OUTPUT/planning-artifacts/epics.md"
  [ -f "$file" ] || return 0

  local epic_count=0
  local story_count=0

  # Extract epic headers: "## Epic N: Title" or "### Epic N: Title"
  # shellcheck disable=SC2094
  while IFS= read -r line; do
    if [[ "$line" =~ ^##\ Epic\ ([0-9]+):\ (.+) ]]; then
      local epic_num="${BASH_REMATCH[1]}"
      local epic_title="${BASH_REMATCH[2]}"
      # Count stories under this epic
      local stories
      # shellcheck disable=SC2094
      stories=$(grep -cE "^### Story ${epic_num}\." "$file" 2>/dev/null || echo "0")
      store_pattern "bmad:epic:$epic_num" "Epic $epic_num: $epic_title ($stories stories)"
      epic_count=$((epic_count + 1))
    fi
  done < "$file"

  # Extract story headers: "### Story N.M: Title"
  while IFS= read -r line; do
    if [[ "$line" =~ ^###\ Story\ ([0-9]+)\.([0-9]+):\ (.+) ]]; then
      local epic="${BASH_REMATCH[1]}"
      local story="${BASH_REMATCH[2]}"
      local title="${BASH_REMATCH[3]}"
      store_pattern "bmad:story:${epic}-${story}" "Story $epic.$story: $title"
      story_count=$((story_count + 1))
    fi
  done < "$file"

  echo "  epics: $epic_count, stories: $story_count"
}

sync_sprint_status() {
  local file="$BMAD_OUTPUT/implementation-artifacts/sprint-status.yaml"
  [ -f "$file" ] || return 0

  # Count stories by status using grep/awk (no yq dependency)
  local backlog=0 ready=0 in_progress=0 review=0 done=0

  while IFS=': ' read -r key value; do
    key="${key#"${key%%[! ]*}"}"
    value="${value#"${value%%[! ]*}"}"
    # Skip comment lines, empty lines, and metadata keys
    [[ "$key" =~ ^# ]] && continue
    [[ -z "$key" ]] && continue
    # Only count story and epic status lines under development_status
    case "$value" in
      backlog) backlog=$((backlog + 1)) ;;
      ready-for-dev|ready) ready=$((ready + 1)) ;;
      in-progress) in_progress=$((in_progress + 1)) ;;
      review) review=$((review + 1)) ;;
      done) done=$((done + 1)) ;;
    esac
  done < <(grep -E '^\s+\S+:' "$file" | grep -v '^\s*#')

  local total=$((backlog + ready + in_progress + review + done))
  store_pattern "bmad:sprint:status" "Sprint: $total items ($backlog backlog, $ready ready, $in_progress in-progress, $review review, $done done)"
  echo "  sprint status: $total items synced"
}

sync_product_brief() {
  local file
  file=$(find "$BMAD_OUTPUT/planning-artifacts" -name 'product-brief-*.md' -print -quit 2>/dev/null)
  [ -n "$file" ] && [ -f "$file" ] || return 0

  # Extract the executive summary paragraph (first non-empty line after "## Executive Summary")
  local summary=""
  local in_summary=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^##\ Executive\ Summary ]]; then
      in_summary=1
      continue
    fi
    if [ "$in_summary" -eq 1 ]; then
      # Skip blank lines
      [[ -z "${line// /}" ]] && continue
      # Stop at next heading
      [[ "$line" =~ ^## ]] && break
      summary="$line"
      break
    fi
  done < "$file"

  if [ -n "$summary" ]; then
    store_pattern "bmad:brief:summary" "$summary"
    echo "  product brief: synced"
  else
    echo "  product brief: no summary found"
  fi
}

sync_prd() {
  local file="$BMAD_OUTPUT/planning-artifacts/prd.md"
  [ -f "$file" ] || return 0

  # Count unique FR and NFR identifiers (handles "- FR1:", "| FR1 |", etc.)
  local fr_count nfr_count
  fr_count=$(grep -oE 'FR[0-9]+' "$file" 2>/dev/null | sort -u | wc -l | tr -d ' ')
  nfr_count=$(grep -oE 'NFR[0-9]+' "$file" 2>/dev/null | sort -u | wc -l | tr -d ' ')

  # Extract project type from frontmatter
  local project_type=""
  project_type=$(grep 'projectType:' "$file" 2>/dev/null | head -1 | sed 's/.*projectType: *//' || true)

  store_pattern "bmad:prd:summary" "PRD: $fr_count FRs, $nfr_count NFRs, type=$project_type"
  echo "  PRD: $fr_count FRs, $nfr_count NFRs"
}

sync_brainstorming() {
  local dir="$BMAD_OUTPUT/brainstorming"
  [ -d "$dir" ] || return 0

  local count=0
  for file in "$dir"/*.md; do
    [ -f "$file" ] || continue
    local basename
    basename=$(basename "$file" .md)
    # Extract title: first line starting with #
    local title
    title=$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# //' || echo "$basename")
    store_pattern "bmad:brainstorm:$basename" "$title"
    count=$((count + 1))
  done
  echo "  brainstorming files: $count"
}

sync_story_files() {
  local dir="$BMAD_OUTPUT/implementation-artifacts/stories"
  [ -d "$dir" ] || return 0

  local count=0
  for file in "$dir"/*.md; do
    [ -f "$file" ] || continue
    local basename
    basename=$(basename "$file" .md)
    # Extract title from first heading
    local title
    title=$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# //' || echo "$basename")
    # Extract status if present in frontmatter
    local status
    status=$(grep -m1 'status:' "$file" 2>/dev/null | sed 's/.*status: *//' || echo "unknown")
    store_pattern "bmad:story-file:$basename" "$title (status: $status)"
    count=$((count + 1))
  done
  if [ "$count" -gt 0 ]; then
    echo "  story files: $count"
  fi
}

# --- Routing: single file vs full sync ---

sync_file() {
  local file="$1"
  echo "Syncing BMAD artifact: $file"
  case "$file" in
    *architecture-diagram.md)     sync_architecture_decisions ;;
    *epics.md)                    sync_epics ;;
    *sprint-status.yaml)          sync_sprint_status ;;
    *product-brief-*.md)          sync_product_brief ;;
    *prd.md)                      sync_prd ;;
    *brainstorming/*.md)          sync_brainstorming ;;
    *stories/*.md)                sync_story_files ;;
    *)                            echo "  (no extractor for this file type)" ;;
  esac
}

sync_all() {
  echo "Syncing all BMAD artifacts to Claude Flow memory..."
  sync_architecture_decisions
  sync_epics
  sync_sprint_status
  sync_product_brief
  sync_prd
  sync_brainstorming
  sync_story_files
  echo "Done."
}

# --- Main ---

if [ $# -ge 1 ]; then
  sync_file "$1"
else
  sync_all
fi
