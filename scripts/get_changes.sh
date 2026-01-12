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

# Use filter-repo to rewrite the history of the current branch (HEAD) 
# based on the fetched AOSP branch. 
# This does two things at once:
# 1. --path: Isolates only the 'car/app/app-samples/' directory.
# 2. --filename-callback: Renames any file starting with 'github_'.
# The result is a clean, filtered history that preserves the original commits.
echo "Filtering AOSP history and renaming files..."
git filter-repo \
  --source refs/remotes/aosp/androidx-main \
  --target HEAD \
  --path car/app/app-samples/ \
  --filename-callback '
    return filename.replace(b"github_", b"")
  ' \
  --force

echo "History rewrite complete."
