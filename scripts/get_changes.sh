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

AOSP_COMMIT_MAP=""
LOCAL_COMMIT_MAP=""

apply_subtree_commits() {
  local branch="$1"
  local commits="$2"
  local mapping_var="$3"
  local commit
  local commit_msg
  local new_commit

  if [ -z "${commits}" ]; then
    echo "⚠️  No commits to apply to ${SUBTREE_PREFIX} for ${branch}."
    return
  fi

  echo "Preparing filtered branch ${branch} from origin/${TARGET_BRANCH}..."
  git checkout -B "${branch}" "origin/${TARGET_BRANCH}"

  if [ -d "${SUBTREE_PREFIX}" ]; then
    git clean -fdx -- "${SUBTREE_PREFIX}" 2>/dev/null || true
  fi

  if [ -n "${mapping_var}" ]; then
    eval "${mapping_var}=''"
  fi

  for commit in $commits; do
    if [ -z "${commit}" ]; then
      continue
    fi

    commit_msg=$(git log -1 --format="%s" "${commit}")
    echo "  Applying: ${commit_msg}"

    git reset --hard HEAD 2>/dev/null || true

    if git cat-file -e "${commit}:${SUBTREE_PREFIX}" 2>/dev/null; then
      git restore --source="${commit}" --staged --worktree -- "${SUBTREE_PREFIX}" 2>/dev/null || true
    else
      if git ls-files --error-unmatch "${SUBTREE_PREFIX}" >/dev/null 2>&1; then
        git rm -rf "${SUBTREE_PREFIX}" 2>/dev/null || true
      fi
      rm -rf "${SUBTREE_PREFIX}" 2>/dev/null || true
    fi

    if [ -d "${SUBTREE_PREFIX}" ]; then
      git clean -fd -- "${SUBTREE_PREFIX}" 2>/dev/null || true
    fi

    if git diff --cached --quiet; then
      git reset HEAD -- "${SUBTREE_PREFIX}" 2>/dev/null || true
      continue
    fi

    if ! GIT_EDITOR=true git commit -C "${commit}" --allow-empty; then
      echo "❌ Failed to commit filtered changes for ${commit}"
      git reset --hard HEAD
      git checkout "${TARGET_BRANCH}"
      exit 1
    fi

    if [ -n "${mapping_var}" ]; then
      new_commit=$(git rev-parse HEAD)
      eval "${mapping_var}+='${new_commit}|${commit}'$'\n'"
    fi
  done

  git checkout "${TARGET_BRANCH}"
}

cherry_pick_commits() {
  local commits="$1"
  local commit
  local commit_msg

  if [ -z "${commits}" ]; then
    return
  fi

  for commit in $commits; do
    if [ -z "${commit}" ]; then
      continue
    fi

    commit_msg=$(git log -1 --format="%s" "${commit}")
    echo "Cherry-picking: ${commit_msg}"

    if git cherry-pick "${commit}"; then
      continue
    fi

    echo "⚠️  Conflict detected, attempting auto-resolution..."

    git clean -f ${SUBTREE_PREFIX}/local.properties 2>/dev/null || true
    git clean -fdx ${SUBTREE_PREFIX}/build/ 2>/dev/null || true
    git clean -fdx ${SUBTREE_PREFIX}/.gradle/ 2>/dev/null || true
    git clean -fdx ${SUBTREE_PREFIX}/.idea/ 2>/dev/null || true

    CONFLICTED_FILES=$(git diff --name-only --diff-filter=U)
    DELETED_BY_US=$(git diff --name-only --diff-filter=DU 2>/dev/null || true)
    DELETED_BY_THEM=$(git diff --name-only --diff-filter=UD 2>/dev/null || true)

    if [ -n "$DELETED_BY_US" ]; then
      echo "Handling files deleted in main branch:"
      while IFS= read -r file; do
        if [ -n "$file" ]; then
          if [[ "$file" == "${SUBTREE_PREFIX}/"* ]]; then
            echo "  Keeping deletion: $file"
            if [ -e "$file" ]; then
              rm -f "$file" 2>/dev/null || true
            fi
            git rm -f "$file" 2>/dev/null || git add "$file" 2>/dev/null || true
          else
            echo "  Keeping local (outside AOSP path): $file"
            git checkout --ours "$file" 2>/dev/null || true
            git add "$file" 2>/dev/null || true
          fi
        fi
      done < <(echo "$DELETED_BY_US")
    fi

    if [ -n "$DELETED_BY_THEM" ]; then
      echo "Handling files deleted by AOSP:"
      while IFS= read -r file; do
        if [ -n "$file" ]; then
          if [[ "$file" == "${SUBTREE_PREFIX}/"* ]]; then
            echo "  Removing: $file"
            git rm "$file" 2>/dev/null || true
          else
            echo "  Keeping local (outside AOSP path): $file"
            git checkout --ours "$file" 2>/dev/null || true
            git add "$file" 2>/dev/null || true
          fi
        fi
      done < <(echo "$DELETED_BY_THEM")
    fi

    if [ -n "$CONFLICTED_FILES" ]; then
      echo "Resolving conflicts in: $CONFLICTED_FILES"
      while IFS= read -r file; do
        if [ -n "$file" ]; then
          if [[ "$file" != "${SUBTREE_PREFIX}/"* ]]; then
            echo "  Keeping local (outside AOSP path): $file"
            git checkout --ours "$file" 2>/dev/null || true
            git add "$file" 2>/dev/null || true
          else
            if [ -f "$file" ]; then
              echo "  Taking AOSP version: $file"
              git checkout --theirs "$file" 2>/dev/null || true
              git add "$file" 2>/dev/null || true
            else
              echo "  Removing: $file"
              git rm "$file" 2>/dev/null || true
            fi
          fi
        fi
      done < <(echo "$CONFLICTED_FILES")

      git add -A ${SUBTREE_PREFIX}/ 2>/dev/null || git add -u 2>/dev/null || true
    fi

    if git diff --name-only --diff-filter=U | grep -q .; then
      echo "❌ Cherry-pick failed for commit: ${commit}"
      echo "Unresolved conflicts remain. Please resolve manually."
      echo "Then run: git cherry-pick --continue"
      echo "Or skip: git cherry-pick --skip"
      echo "Or abort: git cherry-pick --abort"
      git branch -D aosp-filtered 2>/dev/null || true
      git branch -D local-filtered 2>/dev/null || true
      exit 1
    fi

    if ! GIT_EDITOR=true git cherry-pick --continue; then
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
        git branch -D local-filtered 2>/dev/null || true
        exit 1
      fi
    fi
  done
}

merge_commits_by_author_time() {
  local queue="$1"

  if [ -z "${queue}" ]; then
    echo ""
    return
  fi

  printf "%s" "${queue}" | sort -t'|' -k2,2n -k3,3n | awk -F'|' '{print $4}'
}

# Add the AOSP repository as a remote if it doesn't exist
if ! git remote | grep -q "${AOSP_REMOTE}"; then
  echo "Adding AOSP remote..."
  git remote add ${AOSP_REMOTE} ${AOSP_URL}
fi

# Fetch the latest changes from the AOSP androidx-main branch and main
echo "Fetching latest changes from AOSP ${AOSP_BRANCH}..."
git fetch ${AOSP_REMOTE} ${AOSP_BRANCH}
git fetch origin ${TARGET_BRANCH}

# Capture local commits ahead of origin to replay after syncing AOSP
LOCAL_COMMITS=$(git log --reverse --format="%H" origin/${TARGET_BRANCH}..${TARGET_BRANCH} -- ${SUBTREE_PREFIX} 2>/dev/null || echo "")

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

# Create branches to work with filtered commits
git branch -D aosp-filtered 2>/dev/null || true
git branch -D local-filtered 2>/dev/null || true

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
    git branch -D aosp-filtered 2>/dev/null || true
    exit 0
  fi
  
  COMMIT_COUNT=$(echo "$NEW_AOSP_COMMITS" | wc -l | tr -d ' ')
  echo "Found ${COMMIT_COUNT} new AOSP commit(s) touching ${SUBTREE_PREFIX}"

  apply_subtree_commits "aosp-filtered" "$NEW_AOSP_COMMITS" "AOSP_COMMIT_MAP"

else
  echo "No previous sync found - performing initial sync..."
  echo "This will take a few minutes but subsequent runs will be instant..."
  
  # For first run, gather recent history that touches the subtree
  # so we can replay it onto our local branch without subtree split
  
  # Get commits that touch our subtree (limit to last 1000 for initial sync)
  echo "Finding recent commits in AOSP that touch ${SUBTREE_PREFIX}..."
  AOSP_COMMITS=$(git log --reverse --format="%H" -1000 \
    ${AOSP_REMOTE}/${AOSP_BRANCH} -- ${SUBTREE_PREFIX})
  
  COMMIT_COUNT=$(echo "$AOSP_COMMITS" | wc -l | tr -d ' ')
  echo "Processing ${COMMIT_COUNT} recent commit(s)..."

  if [ -z "$AOSP_COMMITS" ]; then
    echo "⚠️  No commits found in ${AOSP_REMOTE}/${AOSP_BRANCH} for ${SUBTREE_PREFIX}."
    exit 0
  fi

  apply_subtree_commits "aosp-filtered" "$AOSP_COMMITS" "AOSP_COMMIT_MAP"

fi

LOCAL_FILTERED_COMMITS=""
if [ -n "$LOCAL_COMMITS" ]; then
  apply_subtree_commits "local-filtered" "$LOCAL_COMMITS" "LOCAL_COMMIT_MAP"
  if git show-ref --verify --quiet refs/heads/local-filtered; then
    LOCAL_FILTERED_COMMITS=$(git rev-list origin/${TARGET_BRANCH}..local-filtered --reverse 2>/dev/null || echo "")
  fi
fi

# Determine commits to apply in chronological order
AOSP_FILTERED_COMMITS=""
if git show-ref --verify --quiet refs/heads/aosp-filtered; then
  AOSP_FILTERED_COMMITS=$(git rev-list origin/${TARGET_BRANCH}..aosp-filtered --reverse 2>/dev/null || echo "")
fi

if [ -n "$AOSP_FILTERED_COMMITS" ]; then
  AOSP_COMMIT_COUNT=$(echo "$AOSP_FILTERED_COMMITS" | wc -l | tr -d ' ')
else
  AOSP_COMMIT_COUNT=0
fi

if [ -n "$LOCAL_FILTERED_COMMITS" ]; then
  LOCAL_COMMIT_COUNT=$(echo "$LOCAL_FILTERED_COMMITS" | wc -l | tr -d ' ')
else
  LOCAL_COMMIT_COUNT=0
fi

if [ -z "$AOSP_FILTERED_COMMITS" ] && [ -z "$LOCAL_FILTERED_COMMITS" ]; then
  echo "✅ No new commits to add - already up to date!"
  git branch -D aosp-filtered 2>/dev/null || true
  git branch -D local-filtered 2>/dev/null || true
  exit 0
fi

BRANCH_NAME="${BRANCH_PREFIX}/$(date +%Y-%m-%d)"
echo "Creating branch ${BRANCH_NAME} from origin/${TARGET_BRANCH}..."
git checkout -B ${BRANCH_NAME} origin/${TARGET_BRANCH}

git clean -fdx ${SUBTREE_PREFIX}/ 2>/dev/null || true

COMMIT_METADATA=""
ORDER_COUNTER=0

if [ -n "$AOSP_FILTERED_COMMITS" ]; then
  while IFS= read -r commit; do
    if [ -n "$commit" ]; then
      original_commit=$(printf "%s" "${AOSP_COMMIT_MAP}" | awk -F'|' -v f="$commit" 'BEGIN{found=""} $1==f {found=$2; exit} END{print found}')
      if [ -z "$original_commit" ]; then
        original_commit="$commit"
      fi
      commit_time=$(git show -s --format="%ct" "$original_commit")
      COMMIT_METADATA+="aosp|${commit_time}|${ORDER_COUNTER}|${commit}"$'\n'
      ORDER_COUNTER=$((ORDER_COUNTER + 1))
    fi
  done <<< "$AOSP_FILTERED_COMMITS"
fi

if [ -n "$LOCAL_FILTERED_COMMITS" ]; then
  while IFS= read -r commit; do
    if [ -n "$commit" ]; then
      original_commit=$(printf "%s" "${LOCAL_COMMIT_MAP}" | awk -F'|' -v f="$commit" 'BEGIN{found=""} $1==f {found=$2; exit} END{print found}')
      if [ -z "$original_commit" ]; then
        original_commit="$commit"
      fi
      commit_time=$(git show -s --format="%ct" "$original_commit")
      COMMIT_METADATA+="local|${commit_time}|${ORDER_COUNTER}|${commit}"$'\n'
      ORDER_COUNTER=$((ORDER_COUNTER + 1))
    fi
  done <<< "$LOCAL_FILTERED_COMMITS"
fi

MERGED_COMMIT_LIST=$(merge_commits_by_author_time "${COMMIT_METADATA}")

if [ -n "$MERGED_COMMIT_LIST" ]; then
  echo "Applying ${AOSP_COMMIT_COUNT} AOSP and ${LOCAL_COMMIT_COUNT} local commit(s) in chronological order..."
  cherry_pick_commits "$MERGED_COMMIT_LIST"
fi

echo "✅ Successfully built branch ${BRANCH_NAME} with linear chronological history!"

# Update the sync marker tag for next run
echo "Updating sync marker for future incremental updates..."
# Tag should point to the AOSP commit, not our filtered branch
LATEST_AOSP_COMMIT=$(git log -1 --format="%H" ${AOSP_REMOTE}/${AOSP_BRANCH})
git tag -f ${LAST_SYNC_TAG} ${LATEST_AOSP_COMMIT}
git push origin ${LAST_SYNC_TAG} --force 2>/dev/null || echo "⚠️  Could not push tag (may need manual push)"

# Clean up temporary branches
echo "Cleaning up temporary branch..."
git branch -D aosp-filtered 2>/dev/null || true
git branch -D local-filtered 2>/dev/null || true

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
