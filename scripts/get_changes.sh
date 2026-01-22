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

# Create a branch to work with filtered AOSP commits
git branch -D aosp-filtered 2>/dev/null || true

# Verify the tag exists and resolve it to a commit SHA
if git rev-parse "refs/tags/${LAST_SYNC_TAG}" >/dev/null 2>&1; then
  LAST_SYNCED_AOSP_COMMIT=$(git rev-parse "refs/tags/${LAST_SYNC_TAG}")
  echo "Found last sync marker at AOSP commit: ${LAST_SYNCED_AOSP_COMMIT}"
  echo "Finding new commits since last sync (fast!)..."
  
  # Find commits in AOSP that touch our subtree path since last sync
  # This is MUCH faster than git subtree split
  NEW_AOSP_COMMITS=$(git log --reverse --format="%H" \
    ${LAST_SYNCED_AOSP_COMMIT}..${AOSP_REMOTE}/${AOSP_BRANCH} \
    -- ${SUBTREE_PREFIX} 2>/dev/null || echo "")
  
  if [ -z "$NEW_AOSP_COMMITS" ]; then
    echo "✅ No new commits in AOSP for ${SUBTREE_PREFIX} - already up to date!"
    exit 0
  fi
  
  COMMIT_COUNT=$(echo "$NEW_AOSP_COMMITS" | wc -l | tr -d ' ')
  echo "Found ${COMMIT_COUNT} new AOSP commit(s) touching ${SUBTREE_PREFIX}"
  
  # Create aosp-filtered branch by filtering just the new commits
  # Start from the last synced commit
  git branch aosp-filtered ${LAST_SYNCED_AOSP_COMMIT}
  git checkout aosp-filtered
  
  # Apply each new commit with path filtering
  for commit in $NEW_AOSP_COMMITS; do
    COMMIT_MSG=$(git log -1 --format="%s" $commit)
    echo "  Filtering: ${COMMIT_MSG}"
    
    # Cherry-pick with subdirectory filter
    # This keeps only changes to our subtree path
    if git cherry-pick -n $commit 2>/dev/null; then
      # Remove changes outside our subtree
      git reset HEAD -- . 2>/dev/null || true
      git checkout HEAD -- . 2>/dev/null || true
      git add ${SUBTREE_PREFIX}/ 2>/dev/null || true
      
      # Commit if there are actual changes
      if ! git diff --cached --quiet 2>/dev/null; then
        git commit -C $commit --allow-empty 2>/dev/null || true
      fi
    else
      # If cherry-pick fails, try to extract just the subtree changes
      git cherry-pick --abort 2>/dev/null || true
      
      # Extract the patch for our subtree only
      if git format-patch -1 --stdout $commit -- ${SUBTREE_PREFIX} | \
         git apply --directory="" 2>/dev/null; then
        git add ${SUBTREE_PREFIX}/ 2>/dev/null || true
        if ! git diff --cached --quiet 2>/dev/null; then
          git commit -C $commit --allow-empty 2>/dev/null || true
        fi
      fi
    fi
  done
  
  # Return to previous branch
  git checkout ${TARGET_BRANCH}
  
else
  echo "No previous sync found - performing initial sync..."
  echo "This will take a few minutes but subsequent runs will be instant..."
  
  # For first run, we need to do a full subtree split
  # But we'll be smart about it - only process recent history
  RECENT_AOSP_COMMIT=$(git log -1 --format="%H" ${AOSP_REMOTE}/${AOSP_BRANCH})
  
  # Get commits that touch our subtree (limit to last 1000 for initial sync)
  echo "Finding recent commits in AOSP that touch ${SUBTREE_PREFIX}..."
  AOSP_COMMITS=$(git log --reverse --format="%H" -1000 \
    ${AOSP_REMOTE}/${AOSP_BRANCH} -- ${SUBTREE_PREFIX})
  
  COMMIT_COUNT=$(echo "$AOSP_COMMITS" | wc -l | tr -d ' ')
  echo "Processing ${COMMIT_COUNT} recent commit(s)..."
  
  # Create filtered branch from scratch
  FIRST_COMMIT=$(echo "$AOSP_COMMITS" | head -1)
  git checkout --orphan aosp-filtered $FIRST_COMMIT
  git rm -rf . 2>/dev/null || true
  git checkout $FIRST_COMMIT -- ${SUBTREE_PREFIX} 2>/dev/null || true
  git commit -m "Initial sync from AOSP" --allow-empty
  
  # Apply remaining commits
  for commit in $(echo "$AOSP_COMMITS" | tail -n +2); do
    git cherry-pick -n $commit 2>/dev/null || true
    git reset HEAD -- . 2>/dev/null || true
    git checkout HEAD -- . 2>/dev/null || true
    git add ${SUBTREE_PREFIX}/ 2>/dev/null || true
    if ! git diff --cached --quiet 2>/dev/null; then
      git commit -C $commit --allow-empty 2>/dev/null || true
    fi
  done
  
  git checkout ${TARGET_BRANCH}
  
  # Tag the last synced AOSP commit for next time
  LAST_SYNCED_AOSP_COMMIT=$RECENT_AOSP_COMMIT
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
      
      # Get conflicted files (both content conflicts and modify/delete)
      CONFLICTED=$(git diff --name-only --diff-filter=U)
      DELETED_BY_US=$(git diff --name-only --diff-filter=DU 2>/dev/null || true)
      DELETED_BY_THEM=$(git diff --name-only --diff-filter=UD 2>/dev/null || true)
      
      # Handle modify/delete conflicts first (files deleted in main but modified in AOSP)
      if [ -n "$DELETED_BY_US" ]; then
        echo "Handling files deleted in main branch:"
        while IFS= read -r file; do
          if [ -n "$file" ]; then
            echo "  Keeping deletion: $file"
            # Remove the file if it exists in working tree
            if [ -e "$file" ]; then
              rm -f "$file" 2>/dev/null || true
            fi
            # Mark the deletion as resolved in the index
            git rm -f "$file" 2>/dev/null || git add "$file" 2>/dev/null || true
          fi
        done < <(echo "$DELETED_BY_US")
      fi
      
      # Handle files deleted by AOSP but modified locally
      if [ -n "$DELETED_BY_THEM" ]; then
        echo "Handling files deleted by AOSP:"
        while IFS= read -r file; do
          if [ -n "$file" ]; then
            echo "  Removing: $file"
            git rm "$file" 2>/dev/null || true
          fi
        done < <(echo "$DELETED_BY_THEM")
      fi
      
      # Handle regular content conflicts
      if [ -n "$CONFLICTED" ]; then
        echo "Resolving conflicts..."
        
        # Use process substitution to avoid subshell
        while IFS= read -r file; do
          if [ -n "$file" ]; then
            # Keep README files from our branch (main), take others from incoming (AOSP)
            case "$file" in
              README.md|github_README.md|*/README.md)
                echo "  Keeping local: $file"
                git checkout --ours "$file" 2>/dev/null || true
                git add "$file" 2>/dev/null || true
                ;;
              *)
                if [ -f "$file" ]; then
                  echo "  Taking incoming: $file"
                  git checkout --theirs "$file" 2>/dev/null || true
                  git add "$file" 2>/dev/null || true
                else
                  echo "  Removing: $file"
                  git rm "$file" 2>/dev/null || true
                fi
                ;;
            esac
          fi
        done < <(echo "$CONFLICTED")
        
        # Ensure everything is staged
        git add -A ${SUBTREE_PREFIX}/ 2>/dev/null || true
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
        
        # Get list of conflicted files (both content conflicts and modify/delete)
        CONFLICTED_FILES=$(git diff --name-only --diff-filter=U)
        DELETED_BY_US=$(git diff --name-only --diff-filter=DU 2>/dev/null || true)
        DELETED_BY_THEM=$(git diff --name-only --diff-filter=UD 2>/dev/null || true)
        
        # Handle modify/delete conflicts first (files deleted in main but modified in AOSP)
        if [ -n "$DELETED_BY_US" ]; then
          echo "Handling files deleted in main branch:"
          while IFS= read -r file; do
            if [ -n "$file" ]; then
              echo "  Keeping deletion: $file"
              # Remove the file if it exists in working tree
              if [ -e "$file" ]; then
                rm -f "$file" 2>/dev/null || true
              fi
              # Mark the deletion as resolved in the index
              git rm -f "$file" 2>/dev/null || git add "$file" 2>/dev/null || true
            fi
          done < <(echo "$DELETED_BY_US")
        fi
        
        # Handle files deleted by AOSP but modified locally
        if [ -n "$DELETED_BY_THEM" ]; then
          echo "Handling files deleted by AOSP:"
          while IFS= read -r file; do
            if [ -n "$file" ]; then
              echo "  Removing: $file"
              git rm "$file" 2>/dev/null || true
            fi
          done < <(echo "$DELETED_BY_THEM")
        fi
        
        # Handle regular content conflicts
        if [ -n "$CONFLICTED_FILES" ]; then
          echo "Resolving conflicts in: $CONFLICTED_FILES"
          
          # Resolve each conflicted file - use process substitution to avoid subshell
          while IFS= read -r file; do
            if [ -n "$file" ]; then
              # Keep README files from our branch (main), take others from incoming (AOSP)
              case "$file" in
                README.md|github_README.md|*/README.md)
                  echo "  Keeping local: $file"
                  git checkout --ours "$file" 2>/dev/null || true
                  git add "$file" 2>/dev/null || true
                  ;;
                *)
                  if [ -f "$file" ]; then
                    echo "  Taking incoming: $file"
                    git checkout --theirs "$file" 2>/dev/null || true
                    git add "$file" 2>/dev/null || true
                  else
                    echo "  Removing: $file"
                    git rm "$file" 2>/dev/null || true
                  fi
                  ;;
              esac
            fi
          done < <(echo "$CONFLICTED_FILES")
          
          # Stage all changes to ensure everything is committed
          git add -A ${SUBTREE_PREFIX}/ 2>/dev/null || git add -u 2>/dev/null || true
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
# Tag should point to the AOSP commit, not our filtered branch
LATEST_AOSP_COMMIT=$(git log -1 --format="%H" ${AOSP_REMOTE}/${AOSP_BRANCH})
git tag -f ${LAST_SYNC_TAG} ${LATEST_AOSP_COMMIT}
git push origin ${LAST_SYNC_TAG} --force 2>/dev/null || echo "⚠️  Could not push tag (may need manual push)"

# Clean up temporary branch
echo "Cleaning up temporary branch..."
git branch -D aosp-filtered 2>/dev/null || true

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
