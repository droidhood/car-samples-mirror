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

# Create a temporary directory to clone the AOSP repo and filter it
TEMP_AOSP_DIR=$(mktemp -d)
echo "Cloning AOSP into temporary directory: $TEMP_AOSP_DIR"
git clone --depth 100 --filter=blob:none https://android.googlesource.com/platform/frameworks/support "$TEMP_AOSP_DIR"

# Navigate into the temporary clone
pushd "$TEMP_AOSP_DIR"

# Filter the history to keep only the relevant path and rename files
echo "Filtering history and renaming files in temporary clone..."
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

# Check out the content of the filtered repository
# (filter-repo automatically checks out the latest commit on HEAD)

# Copy the filtered content back to the main repository
popd # Go back to original directory

echo "Copying filtered content to main repository..."
# Ensure the target directory exists and is empty before copying
rm -rf car/app/app-samples/* || true
mkdir -p car/app/app-samples/

# Use 'rsync' to copy files, excluding the .git directory
rsync -a --exclude='.git' "$TEMP_AOSP_DIR/." "car/app/app-samples/"

# Clean up the temporary directory
rm -rf "$TEMP_AOSP_DIR"

echo "AOSP content updated in car/app/app-samples."

# Now, we need to stage the changes and commit them to the weekly-update branch.
# This will create a new commit that is a descendant of 'main'.
git add car/app/app-samples/
git commit -m "Update car/app/app-samples from AOSP" || true # '|| true' to allow no-op if no changes
