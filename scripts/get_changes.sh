#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

# Configuration
AOSP_REMOTE="aosp"
AOSP_URL="https://android.googlesource.com/platform/frameworks/support"
AOSP_BRANCH="androidx-main"
SUBTREE_PREFIX="car/app/app-samples"

# Add the AOSP repository as a remote if it doesn't exist
if ! git remote | grep -q "${AOSP_REMOTE}"; then
  echo "Adding AOSP remote..."
  git remote add ${AOSP_REMOTE} ${AOSP_URL}
fi

# Fetch the latest changes from the AOSP androidx-main branch
echo "Fetching latest changes from AOSP ${AOSP_BRANCH}..."
git fetch ${AOSP_REMOTE} ${AOSP_BRANCH}

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
echo "Finding new commits to cherry-pick..."
MERGE_BASE=$(git merge-base main aosp-filtered 2>/dev/null || echo "")

if [ -z "$MERGE_BASE" ]; then
  echo "⚠️  No common ancestor found - this may be the first sync"
  echo "Merging all AOSP commits..."
  git merge -s subtree aosp-filtered --allow-unrelated-histories \
    -m "Merge AOSP car/app/app-samples from ${AOSP_BRANCH}"
else
  # Get list of new commits in reverse chronological order (oldest first)
  NEW_COMMITS=$(git rev-list ${MERGE_BASE}..aosp-filtered --reverse)
  
  if [ -z "$NEW_COMMITS" ]; then
    echo "✅ No new commits to add - already up to date!"
  else
    COMMIT_COUNT=$(echo "$NEW_COMMITS" | wc -l | tr -d ' ')
    echo "Found ${COMMIT_COUNT} new commit(s) to cherry-pick..."
    
    # Cherry-pick each new commit
    for commit in $NEW_COMMITS; do
      COMMIT_MSG=$(git log -1 --format="%s" $commit)
      echo "Cherry-picking: ${COMMIT_MSG}"
      
      if ! git cherry-pick $commit; then
        echo "❌ Cherry-pick failed for commit: ${commit}"
        echo "Please resolve conflicts manually and run:"
        echo "  git cherry-pick --continue"
        echo "Or abort with:"
        echo "  git cherry-pick --abort"
        git branch -D aosp-filtered 2>/dev/null || true
        exit 1
      fi
    done
    
    echo "✅ Successfully cherry-picked ${COMMIT_COUNT} commit(s)!"
  fi
fi

# Update the sync marker tag for next run
echo "Updating sync marker for future incremental updates..."
git tag -f ${LAST_SYNC_TAG} aosp-filtered
git push origin ${LAST_SYNC_TAG} --force 2>/dev/null || echo "⚠️  Could not push tag (may need manual push)"

# Clean up temporary branch
echo "Cleaning up temporary branch..."
git branch -D aosp-filtered

echo "✅ AOSP content updated successfully!"
