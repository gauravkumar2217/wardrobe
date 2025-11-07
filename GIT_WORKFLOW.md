# Git Push/Pull Guide for plan-b Branch (No Rebase)

## Configuration (Already Set)
- `git config pull.rebase false` - Uses merge strategy for pulls
- `git config branch.plan-b.rebase false` - Ensures plan-b never rebases

## Daily Workflow

### Pull Latest Changes (Merge Strategy)
```bash
git pull origin plan-b
# or simply
git pull
```

### Push Your Changes
```bash
git push origin plan-b
# or simply
git push
```

## If Conflicts Occur

### Option 1: Keep Your Changes (Local)
```bash
git checkout --ours <file>
git add <file>
git commit -m "Resolved conflict keeping local changes"
```

### Option 2: Keep Remote Changes
```bash
git checkout --theirs <file>
git add <file>
git commit -m "Resolved conflict keeping remote changes"
```

### Option 3: Manual Merge
1. Open conflicted files
2. Resolve conflicts manually (look for `<<<<<<<`, `=======`, `>>>>>>>`)
3. Stage resolved files: `git add <file>`
4. Complete merge: `git commit`

## Important Notes

⚠️ **Before First Push**: You need to unblock on GitHub due to API key detection:
1. Visit: https://github.com/gauravkumar2217/wordrope/security/secret-scanning/unblock-secret/359Oon8WrKPIX9GYOgYB3znd0o9
2. Click "Allow secret"
3. Then push: `git push origin plan-b`

✅ **After First Push**: Normal push/pull will work without issues

## Quick Commands Reference

```bash
# Check status
git status

# Pull latest (merge, no rebase)
git pull origin plan-b

# Push changes
git push origin plan-b

# See commit history
git log --oneline --graph -10

# See what's different
git diff origin/plan-b
```

