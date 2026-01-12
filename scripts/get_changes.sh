#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

# Add the AOSP repository as a remote if it doesn't exist
if ! git remote | grep -q 'aosp'; then
  git remote add aosp https://android.googlesource.com/platform/frameworks/support
fi

# Fetch the latest changes from the AOSP androidx-main branch
echo "Fetching latest changes from AOSP..."
git fetch --depth=100 aosp androidx-main

# 1. Reset the current branch (weekly-update) to match the upstream AOSP branch.
echo "Resetting branch to upstream AOSP history..."
git reset --hard aosp/androidx-main

# 2. Filter the history of the current branch (HEAD) in-place.
#    The filename_callback is updated to handle the collision on README.md.
echo "Filtering history and renaming files for the current branch..."
git filter-repo --refs HEAD \
  --path car/app/app-samples/ \
  --filename-callback '
    # If the file is github_README.md, delete it to prevent collision.
    if filename == b"github_README.md":
      return None
    # For other files, rename if they start with github_
    if filename and filename.startswith(b"github_"):
      return filename.replace(b"github_", b"")
    # Otherwise, keep the original filename
    return filename
  ' \
  --force

echo "History rewrite complete."