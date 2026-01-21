# Scripts Documentation

## Overview

This directory contains scripts to manage syncing AOSP changes and maintaining a linear git history.

## Scripts

### get_changes.sh

Syncs changes from AOSP `androidx-main` branch to this repository.

**Key Features:**
- Creates a new branch from main (ensuring clean rebase base)
- Uses cherry-pick instead of merge (linear history)
- Automatically handles common conflicts
- Names branches with date: `weekly-update/YYYY-MM-DD`

**Usage:**
```bash
./scripts/get_changes.sh
```

**Environment Variables:**
- `TARGET_BRANCH`: Base branch for updates (default: `main`)

**Workflow:**
1. Script creates a new branch `weekly-update/YYYY-MM-DD` from latest `main`
2. Cherry-picks new commits from AOSP (maintains linear history)
3. Auto-resolves common conflicts (build files, etc.)
4. Push the branch and create a PR
5. PR can be rebased onto main without conflicts

**Why No Merge Commits?**
- Merge commits complicate rebasing
- Linear history is easier to review and bisect
- Consistent with linearized main branch

### rebase_branch.sh

Rebases existing branches onto main with automatic conflict resolution.

**Usage:**
```bash
./scripts/rebase_branch.sh <branch-name> [target-branch]
```

**Example:**
```bash
# Rebase weekly-update branch onto main
./scripts/rebase_branch.sh weekly-update/2026-01-20 main
```

**Features:**
- Creates automatic backup before rebasing
- Auto-resolves conflicts in build artifacts
- Handles untracked files that block rebasing
- Skips empty commits automatically

**What It Does:**
1. Creates a backup branch with timestamp
2. Cleans untracked files (build/, .gradle/, etc.)
3. Rebases onto target branch
4. Auto-resolves conflicts using incoming changes
5. Reports success and provides next steps

### linearize_history.sh

Linearizes the entire git history by removing all merge commits.

**Usage:**
```bash
./scripts/linearize_history.sh
```

⚠️ **Warning:** This rewrites git history. Use with caution.

**When to Use:**
- After accumulating many merge commits
- To clean up history before a major milestone
- When switching to a linear workflow

**Note:** After running, you'll need to force push: `git push --force-with-lease origin main`

## Workflow for Maintaining Linear History

### Initial Setup (Done)
1. ✅ Main branch history linearized
2. ✅ Scripts updated to use cherry-pick instead of merge
3. ✅ Auto-conflict resolution implemented

### Weekly Update Process

1. **Fetch AOSP changes:**
   ```bash
   ./scripts/get_changes.sh
   ```

2. **Push and create PR:**
   ```bash
   git push -u origin weekly-update/$(date +%Y-%m-%d)
   ```

3. **Review and merge:**
   - Review changes in PR
   - Rebase if needed: `git pull --rebase origin main`
   - Merge using **Rebase and merge** on GitHub (not merge commit)

### Handling Existing Branches with Merge Commits

If you have existing branches created before these changes:

```bash
# Rebase old branch onto linearized main
./scripts/rebase_branch.sh weekly-update/2026-01-20

# Push (force required due to history rewrite)
git push -f origin weekly-update/2026-01-20
```

## Troubleshooting

### "Conflicts when rebasing"
- Use `rebase_branch.sh` which auto-resolves most conflicts
- For manual resolution: check build artifacts and take incoming changes

### "Branch has diverged"
- This happens after main is linearized
- Use `rebase_branch.sh` to rebase the branch
- Or recreate the branch: `git checkout -b new-branch origin/main && git cherry-pick <commits>`

### "Empty commits during rebase"
- Scripts automatically skip empty commits
- This is normal after linearization (duplicate commits)

## Best Practices

1. **Always start from main:** `get_changes.sh` now does this automatically
2. **Use rebase, not merge:** Maintains linear history
3. **Clean before operations:** Scripts clean build artifacts automatically
4. **Review before force push:** Force pushing rewrites history
5. **Keep backups:** `rebase_branch.sh` creates automatic backups

## Migration Guide

### For Existing Branches

If you have branches created with the old script (with merge commits):

**Option 1: Rebase (Recommended)**
```bash
./scripts/rebase_branch.sh your-branch-name
git push -f origin your-branch-name
```

**Option 2: Recreate**
```bash
git checkout -b your-branch-new origin/main
git cherry-pick commit1 commit2 commit3  # Pick your changes
git push -u origin your-branch-new
```

### For Main Branch

Main has already been linearized. To keep it linear:
- Use "Rebase and merge" when merging PRs
- Never use "Create a merge commit"
- Squash commits if they're redundant

## Technical Details

### Why Cherry-Pick Instead of Merge?

**Old Approach (Merge):**
```
main: A -- B -- C ----------- M (merge commit)
                  \         /
aosp:              D -- E -- F
```

**New Approach (Cherry-Pick/Rebase):**
```
main: A -- B -- C -- D' -- E' -- F'
```

The new approach:
- ✅ Linear history (easier to read/bisect)
- ✅ Clean rebases (no merge conflicts from structure)
- ✅ Consistent with main branch
- ✅ Better for code review

### Conflict Resolution Strategy

Scripts use `--theirs` strategy for conflicts:
- Build files: Use incoming (AOSP) version
- Code files: Use incoming (AOSP) version
- Rationale: AOSP is the source of truth for samples

You can override by manually resolving conflicts when prompted.
