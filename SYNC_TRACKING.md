# AOSP Sync Tracking

## Overview

This repository syncs code from the AOSP (Android Open Source Project) `car/app/app-samples` subtree. To track which AOSP commits have been synced, we use a simple config file instead of git tags.

## Sync Marker File

**File**: `.last-sync-commit`

This file contains the SHA of the last AOSP commit that was successfully synced to the main branch. The sync script (`scripts/get_changes.sh`) reads this file to determine which commits need to be pulled in the next sync.

### Format

```
# Last AOSP sync commit
# This file tracks the last commit from aosp/androidx-main that was synced
# DO NOT manually edit unless you know what you're doing
<commit-sha>
```

- Lines starting with `#` are comments
- The commit SHA should be a full 40-character SHA from `aosp/androidx-main`
- Blank lines are ignored

## Why Not Use Git Tags?

Previously, we used a git tag (`last-aosp-sync`) to track sync progress. However, this caused issues because:

1. The tag pointed to commits in the AOSP repository, which contains large files (>100MB)
2. GitHub rejects pushes of tags that reference commits with files exceeding 100MB
3. Our mirror repository only contains the `car/app/app-samples` subtree and doesn't have these large files

By using a config file instead:
- ✅ No GitHub file size limit issues
- ✅ The file is tracked in git history (auditable)
- ✅ Simpler to update (no force-push required)
- ✅ More explicit and easier to understand

## Duplicate Detection

The sync script also includes duplicate detection to prevent re-syncing commits that were already applied with different SHAs (due to rebasing or other history modifications).

### How It Works

1. The script finds new commits in AOSP since the last sync marker
2. For each commit, it extracts the Gerrit `Change-Id` from the commit message
3. It searches for matching `Change-Id` values in the main branch
4. Commits with matching `Change-Id` are skipped (they're duplicates)
5. Only genuinely new commits are applied

### Verification

Run `scripts/verify_duplicates.sh` to check:
- Current sync marker position
- Which commits would be synced
- Which commits would be skipped as duplicates

## Manual Updates

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

## Current Status

As of 2026-01-26, the sync marker is at:
- **Commit**: `8d16ed772cfb944f026a46f14f11bc236d178e98`
- **Date**: 2026-01-11
- **Message**: Merge "[Showcase] Stop requesting notifications not available on device's android version" into androidx-main

## Troubleshooting

### Sync marker file is missing
If the `.last-sync-commit` file is missing, the script will abort to avoid replaying the entire AOSP history. Create the file with the appropriate commit SHA before running the sync.

### Duplicate commits in PR
If PRs contain duplicate commits (commits that were already synced), it usually means:
1. The sync marker is pointing to the wrong commit
2. The AOSP history was rebased/modified after the marker was set

Run `scripts/verify_duplicates.sh` to diagnose the issue.

### Finding the correct sync marker
To find the latest AOSP commit that's already in main:
1. Look at recent commits in main: `git log origin/main -- car/app/app-samples`
2. For each commit, check if it exists in AOSP by comparing `Change-Id`
3. Set the marker to the most recent AOSP commit that's fully synced to main
