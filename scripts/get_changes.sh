#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

# Add the AOSP repository as a remote if it doesn't exist
if ! git remote | grep -q 'aosp'; then
  git remote add aosp https://android.googlesource.com/platform/frameworks/support
fi

# Fetch the latest changes from the AOSP androidx-main branch
echo "Fetching latest changes from AOSP..."
git fetch aosp androidx-main

# Pull the latest changes from the subtree, replaying the original commits
echo "Pulling latest changes from Aosp subtree..."
git subtree pull --prefix=car/app/app-samples aosp androidx-main

echo "AOSP content updated."
