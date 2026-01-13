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

# Create a temporary directory to clone the AOSP repo
TEMP_AOSP_DIR=$(mktemp -d)
echo "Cloning AOSP into temporary directory: $TEMP_AOSP_DIR"
git clone https://android.googlesource.com/platform/frameworks/support "$TEMP_AOSP_DIR"

# Navigate into the temporary clone
pushd "$TEMP_AOSP_DIR"

# Filter the history to keep only the relevant path and flatten it to the root
echo "Filtering AOSP content for car/app/app-samples..."
# Using --path and then handling moves in the main repo to resolve collisions
git filter-repo --path car/app/app-samples/ --force

popd # Go back to original directory

# Create a temporary staging directory in the main repository for collision resolution
TEMP_STAGING_DIR=$(mktemp -d)

echo "Copying filtered content to temporary staging directory: $TEMP_STAGING_DIR"
# Use 'rsync' to copy files from the filtered temporary AOSP clone to the staging directory
# The filter-repo --path should have flattened car/app/app-samples to the root of TEMP_AOSP_DIR
rsync -a --exclude='.git' "$TEMP_AOSP_DIR/car/app/app-samples/." "$TEMP_STAGING_DIR/"

echo "Resolving naming collisions in staging directory..."
# Iterate through files in the staging directory to resolve naming conflicts
find "$TEMP_STAGING_DIR" -type f \( -name "github_*.gradle" -o -name "github_*.properties" \) | while read -r github_file; do
  dir=$(dirname "$github_file")
  filename=$(basename "$github_file")
  # Remove 'github_' prefix to get the target name
  target_filename="${filename#github_}"
  target_path="$dir/$target_filename"

  if [[ -f "$target_path" ]]; then
    # Collision detected: A non-github_ prefixed file with the same target name already exists.
    # The user wants the non-github_ prefixed file to take precedence, so delete the github_ prefixed one.
    echo "Collision detected: '$target_path' exists. Deleting redundant '$github_file'."
    rm "$github_file"
  else
    # No collision: Safely remove 'github_' prefix.
    echo "No collision for '$github_file'. Renaming to '$target_path'."
    mv "$github_file" "$target_path"
  fi
done

# Handle github_README.md deletion if it exists
find "$TEMP_STAGING_DIR" -type f -name "github_README.md" | while read -r readme_file; do
  echo "Deleting '$readme_file' to prevent collision."
  rm "$readme_file"
done

echo "Copying resolved content to main repository's car/app/app-samples."
# Ensure the target directory exists and is empty before copying
rm -rf car/app/app-samples/* || true
mkdir -p car/app/app-samples/

# Copy processed files from staging to the final destination
rsync -a "$TEMP_STAGING_DIR/." "car/app/app-samples/"

# Clean up temporary directories
rm -rf "$TEMP_AOSP_DIR"
rm -rf "$TEMP_STAGING_DIR"

echo "AOSP content updated and collisions resolved in car/app/app-samples."

# Now, we need to stage the changes and commit them to the weekly-update branch.
# This will create a new commit that is a descendant of 'main'.
git add car/app/app-samples/
git commit -m "Update car/app/app-samples from AOSP with collision resolution" || true # '|| true' to allow no-op if no changes