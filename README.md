# Car Samples Mirror

This repo is a mirror of the AOSP changes pushed to [car/app/app-samples](https://android.googlesource.com/platform/frameworks/support/+/refs/heads/androidx-main/car/app/app-samples) from the AndroidX repository.

By using this repo, you don't need to clone the whole AndroidX repository.

This project would be redundant if Google would update their [car samples repo on GitHub](https://github.com/android/car-samples) more often.

## Table of Contents
- [Overview](#overview)
- [Mirror Setup](#mirror-setup)
- [Sync Tracking](#sync-tracking)
- [Updating the Mirror](#updating-the-mirror)
- [Making Local Changes](#making-local-changes)
- [Troubleshooting](#troubleshooting)

## Overview

This repository mirrors the `car/app/app-samples` directory from the AOSP repository:
- **Source**: https://android.googlesource.com/platform/frameworks/support
- **Branch**: androidx-main
- **Mirrored Path**: `car/app/app-samples`

## Mirror Setup

### Strategy: Git Subtree

We use **git subtree** to maintain this mirror because it:
- ✅ Preserves complete commit history from AOSP
- ✅ Allows making local modifications when needed
- ✅ Creates a self-contained repository (no external dependencies)
- ✅ Maintains original commit SHAs and metadata

### Initial Setup (Already Complete)

The initial subtree was created using:

```bash
# Add AOSP as a remote
git remote add aosp https://android.googlesource.com/platform/frameworks/support

# Fetch the AOSP repository
git fetch aosp androidx-main

# Add the subtree (this was done when the repo was created)
git subtree add --prefix=car/app/app-samples aosp androidx-main --squash
```

### Verifying History Preservation

To verify that AOSP commits are preserved in your history:

```bash
# Check if a specific AOSP commit exists in your history
git log --all --oneline | grep <commit-sha>

# View the full history of the mirrored directory
git log -- car/app/app-samples

# Compare with AOSP
git fetch aosp androidx-main
git log aosp/androidx-main -- car/app/app-samples
```

## Sync Tracking

### Sync Marker File

**File**: `.last-sync-commit`

This file contains the SHA of the last AOSP commit that was successfully synced to the main branch. The sync script (`scripts/get_changes.sh`) reads this file to determine which commits need to be pulled in the next sync.

#### Format

```
# Last AOSP sync commit
# This file tracks the last commit from aosp/androidx-main that was synced
# DO NOT manually edit unless you know what you're doing
<commit-sha>
```

- Lines starting with `#` are comments
- The commit SHA should be a full 40-character SHA from `aosp/androidx-main`
- Blank lines are ignored

### Why Not Use Git Tags?

Previously, we used a git tag (`last-aosp-sync`) to track sync progress. However, this caused issues because:

1. The tag pointed to commits in the AOSP repository, which contains large files (>100MB)
2. GitHub rejects pushes of tags that reference commits with files exceeding 100MB
3. Our mirror repository only contains the `car/app/app-samples` subtree and doesn't have these large files

By using a config file instead:
- ✅ No GitHub file size limit issues
- ✅ The file is tracked in git history (auditable)
- ✅ Simpler to update (no force-push required)
- ✅ More explicit and easier to understand

### Duplicate Detection

The sync script includes duplicate detection to prevent re-syncing commits that were already applied with different SHAs (due to rebasing or other history modifications).

#### How It Works

1. The script finds new commits in AOSP since the last sync marker
2. For each commit, it extracts the Gerrit `Change-Id` from the commit message
3. It searches for matching `Change-Id` values in the main branch
4. Commits with matching `Change-Id` are skipped (they're duplicates)
5. Only genuinely new commits are applied

#### Verification

Run `scripts/verify_duplicates.sh` to check:
- Current sync marker position
- Which commits would be synced
- Which commits would be skipped as duplicates

## Updating the Mirror

### Automated Updates

A GitHub Actions workflow (`.github/workflows/weekly_mirror.yml`) runs weekly to:
1. Create a new branch named `weekly-update/YYYY-MM-DD`
2. Run `scripts/get_changes.sh` to pull latest changes
3. Create a Pull Request if changes are found

### Manual Updates

To manually update the mirror:

```bash
# Run the update script
./scripts/get_changes.sh

# Or manually:
git fetch aosp androidx-main
git subtree pull --prefix=car/app/app-samples aosp androidx-main
```

### Manual Sync Marker Updates

If you need to manually update the sync marker:

1. **Find the correct AOSP commit SHA**:
   ```bash
   git log aosp/androidx-main -- car/app/app-samples
   ```

2. **Update the config file**:
   ```bash
   echo "# Last AOSP sync commit
   # This file tracks the last commit from aosp/androidx-main that was synced
   # DO NOT manually edit unless you know what you're doing
   <commit-sha>" > .last-sync-commit
   ```

3. **Commit the change**:
   ```bash
   git add .last-sync-commit
   git commit -m "Update sync marker to <commit-sha>"
   git push origin main
   ```

## Making Local Changes

You can make local changes to the mirrored code:

1. Create a feature branch
2. Make your changes to files in `car/app/app-samples/`
3. Commit and push

When pulling future AOSP updates, git subtree will merge changes automatically, resolving conflicts if needed.

## Troubleshooting

### Merge Conflicts

If you encounter conflicts during `git subtree pull`:

```bash
# Resolve conflicts manually in the files
git add <resolved-files>
git commit
```

### Missing Commits

If commits seem missing:

```bash
# Fetch with more depth
git fetch aosp androidx-main --depth=1000

# Or fetch all history (large download)
git fetch aosp androidx-main --unshallow
```

### Path Issues

If you see "double nesting" or path issues:
- Ensure the `--prefix` path matches exactly: `car/app/app-samples`
- Do not include trailing slashes

### Sync Marker File Missing

If the `.last-sync-commit` file is missing, the script will abort to avoid replaying the entire AOSP history. Create the file with the appropriate commit SHA before running the sync.

### Duplicate Commits in PR

If PRs contain duplicate commits (commits that were already synced), it usually means:
1. The sync marker is pointing to the wrong commit
2. The AOSP history was rebased/modified after the marker was set

Run `scripts/verify_duplicates.sh` to diagnose the issue.

### Finding the Correct Sync Marker

To find the latest AOSP commit that's already in main:
1. Look at recent commits in main: `git log origin/main -- car/app/app-samples`
2. For each commit, check if it exists in AOSP by comparing `Change-Id`
3. Set the marker to the most recent AOSP commit that's fully synced to main

## Alternative: Git Subtree Split

If you ever need to extract just the subtree history:

```bash
git subtree split --prefix=car/app/app-samples --branch=subtree-only
```

## References

- [Git Subtree Documentation](https://git-scm.com/book/en/v2/Git-Tools-Advanced-Merging)
- [AOSP Repository](https://android.googlesource.com/platform/frameworks/support)
- [Atlassian Git Subtree Tutorial](https://www.atlassian.com/git/tutorials/git-subtree)
