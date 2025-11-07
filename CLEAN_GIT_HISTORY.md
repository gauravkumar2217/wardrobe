# Instructions to Remove API Keys from Git History

## Option 1: Use BFG Repo-Cleaner (Recommended - Easiest)

1. Download BFG Repo-Cleaner from: https://rtyley.github.io/bfg-repo-cleaner/
   (Requires Java - download from https://www.java.com if needed)

2. Create a file `keys.txt` with your API keys (one per line):
   ```
   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
   AIzaSyBQHIBtvLWP9spv2VF9lYrPpYqdS_gIB20
   ```

3. Run BFG to replace secrets:
   ```bash
   java -jar bfg.jar --replace-text keys.txt
   ```

4. Clean up and force push:
   ```bash
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   git push --force --all
   ```

## Option 2: Use GitHub's Secret Scanning Unblock (Temporary)

1. Visit the URL from the error message to temporarily unblock:
   https://github.com/gauravkumar2217/wordrope/security/secret-scanning/unblock-secret/359Oon8WrKPIX9GYOgYB3znd0o9

2. This allows you to push once, but you should still clean history

## Option 3: Manual Git History Rewrite (Current Attempt)

The current code is already clean (uses .env). The issue is the old commit in remote.

Run these commands to clean and force push:

```bash
# Clean up filter-branch backups
git for-each-ref --format="delete %(refname)" refs/original | git update-ref --stdin
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push (WARNING: This rewrites history)
git push --force origin plan-b
```

**IMPORTANT**: Force pushing rewrites history. Make sure your team is aware!

