#!/bin/bash
# Script to rebase a branch onto main with automatic conflict resolution
# Usage: ./rebase_branch.sh <branch-name> [target-branch]
#
# This script helps rebase weekly-update branches onto main by:
# 1. Creating a backup of the branch
# 2. Rebasing onto main with automatic conflict resolution
# 3. Handling build artifacts and untracked files

set -e

BRANCH_NAME="${1}"
TARGET_BRANCH="${2:-main}"

if [ -z "$BRANCH_NAME" ]; then
  echo "Usage: $0 <branch-name> [target-branch]"
  echo ""
  echo "Example:"
  echo "  $0 weekly-update/2026-01-20 main"
  exit 1
fi

echo "🔄 Rebasing ${BRANCH_NAME} onto ${TARGET_BRANCH}..."
echo ""

# Fetch latest
echo "Fetching latest changes..."
git fetch origin

# Check if branch exists
if ! git rev-parse --verify "${BRANCH_NAME}" >/dev/null 2>&1; then
  echo "❌ Branch ${BRANCH_NAME} does not exist"
  exit 1
fi

# Create backup
BACKUP_BRANCH="${BRANCH_NAME}-backup-$(date +%Y%m%d-%H%M%S)"
echo "Creating backup: ${BACKUP_BRANCH}"
git branch ${BACKUP_BRANCH} ${BRANCH_NAME}

# Checkout the branch
echo "Checking out ${BRANCH_NAME}..."
git checkout ${BRANCH_NAME}

# Clean untracked files
echo "Cleaning untracked files..."
git clean -fdx car/app/app-samples/ 2>/dev/null || true

# Start the rebase
echo "Starting rebase onto ${TARGET_BRANCH}..."
if git rebase origin/${TARGET_BRANCH} --empty=drop; then
  echo "✅ Rebase completed successfully!"
else
  echo "⚠️  Rebase has conflicts, attempting auto-resolution..."
  
  # Auto-resolve conflicts loop
  count=0
  while [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; do
    count=$((count + 1))
    
    if [ $count -gt 100 ]; then
      echo "❌ Too many conflicts. Manual intervention required."
      echo "Backup available at: ${BACKUP_BRANCH}"
      exit 1
    fi
    
    # Clean untracked files
    git clean -f car/app/app-samples/local.properties 2>/dev/null || true
    git clean -fdx car/app/app-samples/build/ 2>/dev/null || true
    git clean -fdx car/app/app-samples/.gradle/ 2>/dev/null || true
    git clean -fdx car/app/app-samples/.idea/ 2>/dev/null || true
    git clean -fdx car/app/app-samples/**/build/ 2>/dev/null || true
    
    # Resolve conflicts by taking incoming version
    git diff --name-only --diff-filter=U 2>/dev/null | while IFS= read -r file; do
      if [ -f "$file" ]; then
        echo "  Resolving: $file (taking incoming)"
        git checkout --theirs "$file" && git add "$file"
      else
        git rm "$file" 2>/dev/null || true
      fi
    done
    
    # Try to continue
    if git -c core.editor=true rebase --continue 2>&1 | tee /tmp/rebase_output.txt; then
      if [ ! -d .git/rebase-merge ] && [ ! -d .git/rebase-apply ]; then
        echo "✅ Rebase completed!"
        break
      fi
    else
      if grep -q "nothing to commit\|The previous cherry-pick is now empty" /tmp/rebase_output.txt; then
        echo "  Skipping empty commit..."
        git rebase --skip || true
      elif grep -q "untracked working tree files would be overwritten" /tmp/rebase_output.txt; then
        echo "  Cleaning blocking files..."
        continue
      else
        echo "❌ Rebase failed. Manual intervention required."
        echo "Backup available at: ${BACKUP_BRANCH}"
        cat /tmp/rebase_output.txt
        exit 1
      fi
    fi
  done
fi

echo ""
echo "✅ Branch ${BRANCH_NAME} successfully rebased onto ${TARGET_BRANCH}"
echo "📋 Backup available at: ${BACKUP_BRANCH}"
echo ""
echo "To push the rebased branch (force required):"
echo "   git push -f origin ${BRANCH_NAME}"
echo ""
echo "To delete the backup:"
echo "   git branch -D ${BACKUP_BRANCH}"
