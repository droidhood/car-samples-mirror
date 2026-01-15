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
git fetch ${AOSP_REMOTE} ${AOSP_BRANCH} --depth=100

# Check if there are any new commits to pull
LAST_SUBTREE_COMMIT=$(git log --grep="git-subtree-dir: ${SUBTREE_PREFIX}" --format="%H" -1 2>/dev/null || echo "")
if [ -n "${LAST_SUBTREE_COMMIT}" ]; then
  echo "Last subtree merge was at commit: ${LAST_SUBTREE_COMMIT}"
fi

# Pull the latest changes from the subtree, replaying the original commits
# The --squash flag can be used to create a single commit instead of replaying all commits
# Remove --squash to preserve full history (recommended for your use case)
echo "Pulling latest changes from AOSP subtree..."
echo "This may take a few minutes and will preserve all AOSP commit history..."
git subtree pull --prefix=${SUBTREE_PREFIX} ${AOSP_REMOTE} ${AOSP_BRANCH} -m "Merge AOSP car/app/app-samples from ${AOSP_BRANCH}"

echo "✅ AOSP content updated successfully!"
echo "New commits have been merged into car/app/app-samples/"
