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
#    This gives us the complete, unfiltered history to work with.
echo "Resetting branch to upstream AOSP history..."
git reset --hard aosp/androidx-main

# 2. Filter the history of the current branch (HEAD) in-place.
#    The filename_callback is updated to handle cases where the filename is None.
echo "Filtering history and renaming files for the current branch..."
git filter-repo --refs HEAD \
  --path car/app/app-samples/ \
  --filename-callback \
  '\
    # Return the filename, replacing "github_" if the filename is not None.
    return filename.replace(b"github_", b"") if filename else filename
  ' \
  --force

echo "History rewrite complete."
