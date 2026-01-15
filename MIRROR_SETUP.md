# Mirror Repository Setup Documentation

## Overview
This repository is a mirror of the `car/app/app-samples` directory from the AOSP (Android Open Source Project) repository at:
- **Source**: https://android.googlesource.com/platform/frameworks/support
- **Branch**: androidx-main
- **Mirrored Path**: `car/app/app-samples`

## Strategy: Git Subtree

We use **git subtree** to maintain this mirror because it:
- ✅ Preserves complete commit history from AOSP
- ✅ Allows making local modifications when needed
- ✅ Creates a self-contained repository (no external dependencies)
- ✅ Maintains original commit SHAs and metadata

## Initial Setup (Already Complete)

The initial subtree was created using:

```bash
# Add AOSP as a remote
git remote add aosp https://android.googlesource.com/platform/frameworks/support

# Fetch the AOSP repository
git fetch aosp androidx-main

# Add the subtree (this was done when the repo was created)
git subtree add --prefix=car/app/app-samples aosp androidx-main --squash
```

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

## Verifying History Preservation

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

## Alternative: Git Subtree Split

If you ever need to extract just the subtree history:

```bash
git subtree split --prefix=car/app/app-samples --branch=subtree-only
```

## References
- [Git Subtree Documentation](https://git-scm.com/book/en/v2/Git-Tools-Advanced-Merging)
- [AOSP Repository](https://android.googlesource.com/platform/frameworks/support)
- [Atlassian Git Subtree Tutorial](https://www.atlassian.com/git/tutorials/git-subtree)
