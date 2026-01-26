#!/bin/bash
# Verification script to test duplicate detection logic
# This script checks which AOSP commits are already in main

set -e

AOSP_REMOTE="aosp"
AOSP_BRANCH="androidx-main"
SUBTREE_PREFIX="car/app/app-samples"
TARGET_BRANCH="main"
SYNC_MARKER_FILE=".last-sync-commit"

# Function to check if a commit already exists in main by comparing Change-Id
commit_exists_in_main() {
  local commit="$1"
  
  # Extract Change-Id from commit message body
  local change_id=$(git log -1 --format="%b" "$commit" 2>/dev/null | grep -o "Change-Id: I[a-f0-9]*" | head -1)
  
  if [ -z "$change_id" ]; then
    # No Change-Id found, can't determine if duplicate
    return 1
  fi
  
  # Search for this Change-Id in origin/main's history
  if git log origin/main --format="%b" | grep -q "$change_id"; then
    return 0  # Exists in main
  else
    return 1  # Doesn't exist in main
  fi
}

echo "=========================================="
echo "Duplicate Detection Verification Script"
echo "=========================================="
echo ""

# Fetch latest
echo "Fetching latest changes..."
git fetch ${AOSP_REMOTE} ${AOSP_BRANCH} >/dev/null 2>&1
git fetch origin ${TARGET_BRANCH} >/dev/null 2>&1

# Read last sync commit from config file
if [ -f "${SYNC_MARKER_FILE}" ]; then
  LAST_SYNCED_AOSP_COMMIT=$(grep -v '^#' "${SYNC_MARKER_FILE}" | grep -v '^$' | head -1)
  echo "Current sync marker: ${SYNC_MARKER_FILE} -> ${LAST_SYNCED_AOSP_COMMIT:0:12}"
  git log -1 --format="  %s (%ad)" --date=short ${LAST_SYNCED_AOSP_COMMIT}
else
  echo "❌ Config file ${SYNC_MARKER_FILE} not found!"
  exit 1
fi

echo ""
echo "Finding commits in AOSP since tag..."

# Find commits in AOSP
NEW_AOSP_COMMITS=$(git log --reverse --format="%H" \
  ${LAST_SYNCED_AOSP_COMMIT}..${AOSP_REMOTE}/${AOSP_BRANCH} \
  -- ${SUBTREE_PREFIX} 2>/dev/null || echo "")

if [ -z "$NEW_AOSP_COMMITS" ]; then
  echo "✅ No new commits found - already up to date!"
  exit 0
fi

TOTAL_COUNT=$(echo "$NEW_AOSP_COMMITS" | wc -l | tr -d ' ')
echo "Found ${TOTAL_COUNT} commit(s) in AOSP since tag"
echo ""

# Check each commit
echo "Checking for duplicates..."
echo "----------------------------------------"

DUPLICATE_COUNT=0
NEW_COUNT=0

for commit in $NEW_AOSP_COMMITS; do
  if [ -z "$commit" ]; then
    continue
  fi
  
  commit_msg=$(git log -1 --format="%s" "$commit" 2>/dev/null)
  commit_date=$(git log -1 --format="%ad" --date=short "$commit" 2>/dev/null)
  change_id=$(git log -1 --format="%b" "$commit" 2>/dev/null | grep -o "Change-Id: I[a-f0-9]*" | head -1)
  
  if commit_exists_in_main "$commit"; then
    echo "⏭️  DUPLICATE: ${commit:0:7} ($commit_date) $commit_msg"
    if [ -n "$change_id" ]; then
      echo "    ${change_id}"
    fi
    DUPLICATE_COUNT=$((DUPLICATE_COUNT + 1))
  else
    echo "✅ NEW:       ${commit:0:7} ($commit_date) $commit_msg"
    if [ -n "$change_id" ]; then
      echo "    ${change_id}"
    fi
    NEW_COUNT=$((NEW_COUNT + 1))
  fi
done

echo "----------------------------------------"
echo ""
echo "Summary:"
echo "  Total commits found:   ${TOTAL_COUNT}"
echo "  Duplicates (skip):     ${DUPLICATE_COUNT}"
echo "  New commits (sync):    ${NEW_COUNT}"
echo ""

if [ $DUPLICATE_COUNT -gt 0 ]; then
  echo "⚠️  Warning: ${DUPLICATE_COUNT} duplicate commit(s) detected!"
  echo "   These would be skipped with the new duplicate detection logic."
  echo ""
  echo "Recommendation:"
  echo "  Update ${SYNC_MARKER_FILE} to the latest commit that's already in main."
  echo "  Suggested commit: 8d16ed772cf (Jan 11, 2026)"
  exit 1
else
  echo "✅ No duplicates detected - sync marker is correct!"
  exit 0
fi
