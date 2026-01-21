#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

# Configuration
AOSP_REMOTE="aosp"
AOSP_URL="https://android.googlesource.com/platform/frameworks/support"
AOSP_BRANCH="androidx-main"
SUBTREE_PREFIX="car/app/app-samples"
BRANCH_PREFIX="weekly-update"
TARGET_BRANCH="${TARGET_BRANCH:-main}"

# Add the AOSP repository as a remote if it doesn't exist
if ! git remote | grep -q "${AOSP_REMOTE}"; then
  echo "Adding AOSP remote..."
  git remote add ${AOSP_REMOTE} ${AOSP_URL}
fi

# Fetch the latest changes from the AOSP androidx-main branch and main
echo "Fetching latest changes from AOSP ${AOSP_BRANCH}..."
git fetch ${AOSP_REMOTE} ${AOSP_BRANCH}
git fetch origin ${TARGET_BRANCH}

# Check if there are any new commits to pull
LAST_SUBTREE_COMMIT=$(git log --grep="git-subtree-dir: ${SUBTREE_PREFIX}" --format="%H" -1 2>/dev/null || echo "")
if [ -n "${LAST_SUBTREE_COMMIT}" ]; then
  echo "Last subtree merge was at commit: ${LAST_SUBTREE_COMMIT}"
fi

# Pull the latest changes from the subtree using split to ensure only the target directory is included
echo "Pulling latest changes from AOSP subtree..."

# Check for last sync tag to enable incremental splitting
LAST_SYNC_TAG="last-aosp-sync"
git fetch origin "refs/tags/${LAST_SYNC_TAG}:refs/tags/${LAST_SYNC_TAG}" 2>/dev/null || true

# Verify the tag exists and resolve it to a commit SHA
if git rev-parse "refs/tags/${LAST_SYNC_TAG}" >/dev/null 2>&1; then
  LAST_SYNCED_COMMIT=$(git rev-parse "refs/tags/${LAST_SYNC_TAG}")
  echo "Found last sync marker at commit: ${LAST_SYNCED_COMMIT}"
  echo "Performing incremental split (much faster!)..."
  
  # Create a temporary branch from the last synced state
  git branch -f aosp-base ${LAST_SYNCED_COMMIT}
  
  # Perform incremental split - only process new commits
  git subtree split --prefix=car/app/app-samples --branch=aosp-filtered \
    --onto=aosp-base ${AOSP_REMOTE}/${AOSP_BRANCH}
  
  # Clean up temporary branch
  git branch -D aosp-base
else
  echo "No previous sync found - performing full split..."
  echo "This may take a few minutes and will preserve all AOSP commit history..."
  echo "(Subsequent runs will be much faster!)"
  
  # Full split on first run
  git subtree split --prefix=car/app/app-samples --branch=aosp-filtered \
    ${AOSP_REMOTE}/${AOSP_BRANCH}
fi

# Find the merge base and get only new commits
echo "Finding new commits to apply..."
MERGE_BASE=$(git merge-base ${TARGET_BRANCH} aosp-filtered 2>/dev/null || echo "")

if [ -z "$MERGE_BASE" ]; then
  echo "⚠️  No common ancestor found - this may be the first sync"
  echo "Creating branch with all AOSP commits..."
  
  # Create a new branch from TARGET_BRANCH
  BRANCH_NAME="${BRANCH_PREFIX}/$(date +%Y-%m-%d)"
  git checkout -B ${BRANCH_NAME} ${TARGET_BRANCH}
  
  # Clean untracked files before rebasing
  git clean -fdx ${SUBTREE_PREFIX}/ 2>/dev/null || true
  
  # Rebase aosp-filtered onto current branch with auto-conflict resolution
  echo "Rebasing AOSP changes onto ${TARGET_BRANCH}..."
  git rebase aosp-filtered || {
    echo "⚠️  Rebase conflicts detected, attempting auto-resolution..."
    
    # Loop to auto-resolve all conflicts
    while [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; do
      # Clean untracked files
      git clean -f ${SUBTREE_PREFIX}/local.properties 2>/dev/null || true
      git clean -fdx ${SUBTREE_PREFIX}/build/ 2>/dev/null || true
      git clean -fdx ${SUBTREE_PREFIX}/.gradle/ 2>/dev/null || true
      git clean -fdx ${SUBTREE_PREFIX}/.idea/ 2>/dev/null || true
      
      # Get conflicted files
      CONFLICTED=$(git diff --name-only --diff-filter=U)
      
      if [ -n "$CONFLICTED" ]; then
        echo "Resolving conflicts..."
        echo "$CONFLICTED" | while IFS= read -r file; do
          if [ -n "$file" ]; then
            # Keep README.md from our branch (main), take others from incoming (AOSP)
            if [ "$file" = "README.md" ]; then
              echo "  Keeping local README.md"
              git checkout --ours "$file" 2>/dev/null || true
            elif [ -f "$file" ]; then
              git checkout --theirs "$file" 2>/dev/null || true
            else
              git rm "$file" 2>/dev/null || true
            fi
          fi
        done
        git add -A ${SUBTREE_PREFIX}/ 2>/dev/null || true
        # Also add README.md if it was in conflict
        git add README.md 2>/dev/null || true
      fi
      
      # Check if conflicts remain
      if git diff --name-only --diff-filter=U | grep -q .; then
        echo "❌ Rebase failed - unresolved conflicts remain"
        echo "Please resolve conflicts manually and run:"
        echo "  git rebase --continue"
        echo "Or abort with:"
        echo "  git rebase --abort"
        git branch -D aosp-filtered 2>/dev/null || true
        exit 1
      fi
      
      # Continue rebase
      if GIT_EDITOR=true git rebase --continue 2>&1 | tee /tmp/rebase_out.txt; then
        if [ ! -d .git/rebase-merge ] && [ ! -d .git/rebase-apply ]; then
          echo "✅ Rebase completed!"
          break
        fi
      else
        # Check if it's an empty commit
        if grep -q "No changes\|nothing to commit" /tmp/rebase_out.txt; then
          git rebase --skip || break
        else
          echo "❌ Rebase failed - see errors above"
          git branch -D aosp-filtered 2>/dev/null || true
          exit 1
        fi
      fi
    done
  }
else
  # Get list of new commits in reverse chronological order (oldest first)
  NEW_COMMITS=$(git rev-list ${MERGE_BASE}..aosp-filtered --reverse)
  
  if [ -z "$NEW_COMMITS" ]; then
    echo "✅ No new commits to add - already up to date!"
    git branch -D aosp-filtered
    exit 0
  else
    COMMIT_COUNT=$(echo "$NEW_COMMITS" | wc -l | tr -d ' ')
    echo "Found ${COMMIT_COUNT} new commit(s) to apply..."
    
    # Create a new branch from TARGET_BRANCH (not current branch)
    BRANCH_NAME="${BRANCH_PREFIX}/$(date +%Y-%m-%d)"
    echo "Creating branch ${BRANCH_NAME} from ${TARGET_BRANCH}..."
    git checkout -B ${BRANCH_NAME} origin/${TARGET_BRANCH}
    
    # Clean any untracked files to avoid conflicts
    git clean -fdx ${SUBTREE_PREFIX}/ 2>/dev/null || true
    
    # Cherry-pick each new commit (this creates a linear history)
    for commit in $NEW_COMMITS; do
      COMMIT_MSG=$(git log -1 --format="%s" $commit)
      echo "Cherry-picking: ${COMMIT_MSG}"
      
      if ! git cherry-pick $commit; then
        # If cherry-pick fails, try to auto-resolve with theirs strategy
        echo "⚠️  Conflict detected, attempting auto-resolution..."
        
        # Clean untracked files that might block
        git clean -f ${SUBTREE_PREFIX}/local.properties 2>/dev/null || true
        git clean -fdx ${SUBTREE_PREFIX}/build/ 2>/dev/null || true
        git clean -fdx ${SUBTREE_PREFIX}/.gradle/ 2>/dev/null || true
        git clean -fdx ${SUBTREE_PREFIX}/.idea/ 2>/dev/null || true
        
        # Get list of conflicted files
        CONFLICTED_FILES=$(git diff --name-only --diff-filter=U)
        
        if [ -n "$CONFLICTED_FILES" ]; then
          echo "Resolving conflicts in: $CONFLICTED_FILES"
          
          # Resolve each conflicted file
          echo "$CONFLICTED_FILES" | while IFS= read -r file; do
            if [ -n "$file" ]; then
              # Keep README.md from our branch (main), take others from incoming (AOSP)
              if [ "$file" = "README.md" ]; then
                echo "  Keeping local README.md"
                git checkout --ours "$file" 2>/dev/null || true
              elif [ -f "$file" ]; then
                echo "  Taking incoming version: $file"
                git checkout --theirs "$file" 2>/dev/null || true
              else
                echo "  Removing deleted file: $file"
                git rm "$file" 2>/dev/null || true
              fi
            fi
          done
          
          # Stage all changes (both resolved and unresolved)
          git add -A ${SUBTREE_PREFIX}/ 2>/dev/null || git add -u 2>/dev/null || true
          # Also add README.md if it was in conflict
          git add README.md 2>/dev/null || true
        fi
        
        # Check if there are still unresolved conflicts
        if git diff --name-only --diff-filter=U | grep -q .; then
          echo "❌ Cherry-pick failed for commit: ${commit}"
          echo "Unresolved conflicts remain. Please resolve manually."
          echo "Then run: git cherry-pick --continue"
          echo "Or skip: git cherry-pick --skip"
          echo "Or abort: git cherry-pick --abort"
          git branch -D aosp-filtered 2>/dev/null || true
          exit 1
        fi
        
        # Try to continue with empty editor to auto-accept commit message
        if ! GIT_EDITOR=true git cherry-pick --continue; then
          # If continue fails, check if it's because there are no changes
          if git diff --cached --quiet; then
            echo "  Commit is empty, skipping..."
            git cherry-pick --skip
          else
            echo "❌ Cherry-pick failed for commit: ${commit}"
            echo "Please resolve conflicts manually and run:"
            echo "  git cherry-pick --continue"
            echo "Or skip this commit with:"
            echo "  git cherry-pick --skip"
            echo "Or abort with:"
            echo "  git cherry-pick --abort"
            git branch -D aosp-filtered 2>/dev/null || true
            exit 1
          fi
        fi
      fi
    done
    
    echo "✅ Successfully applied ${COMMIT_COUNT} commit(s) via cherry-pick!"
    echo "Branch ${BRANCH_NAME} can now be rebased onto ${TARGET_BRANCH} without conflicts."
  fi
fi

# Update the sync marker tag for next run
echo "Updating sync marker for future incremental updates..."
git tag -f ${LAST_SYNC_TAG} aosp-filtered
git push origin ${LAST_SYNC_TAG} --force 2>/dev/null || echo "⚠️  Could not push tag (may need manual push)"

# Clean up temporary branch
echo "Cleaning up temporary branch..."
git branch -D aosp-filtered

echo ""
echo "✅ AOSP content updated successfully!"
echo "📋 Summary:"
echo "   - New branch: ${BRANCH_NAME:-main}"
echo "   - Based on: ${TARGET_BRANCH}"
echo "   - Commits: Linear history (no merge commits)"
echo ""
echo "To push and create a PR:"
echo "   git push -u origin ${BRANCH_NAME:-main}"
echo ""
echo "To rebase onto latest main (if needed):"
echo "   git fetch origin ${TARGET_BRANCH}"
echo "   git rebase origin/${TARGET_BRANCH}"
