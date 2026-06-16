#!/bin/bash

# Configuration
REPO_DIR="$HOME/llama.cpp"
REMOTE="origin"
BRANCH="master"

# Ensure we are in the repo directory
if [ ! -d "$REPO_DIR/.git" ]; then
    echo "Error: $REPO_DIR is not a git repository."
    exit 1
fi

cd "$REPO_DIR" || exit 1

# Get size before
SIZE_BEFORE=$(du -sh .git | cut -f1)
echo "Current .git size: $SIZE_BEFORE"

echo "Fetching latest commit from $REMOTE/$BRANCH (depth 1)..."
git fetch --depth 1 "$REMOTE" "$BRANCH"

echo "Updating local branch..."
git reset --hard "$REMOTE/$BRANCH"

echo "Cleaning up history and pruning..."
# Expire reflogs to make old commits unreachable
git reflog expire --expire=now --all
# Aggressive garbage collection and immediate pruning
git gc --prune=now --aggressive

# Get size after
SIZE_AFTER=$(du -sh .git | cut -f1)
echo "Cleanup complete."
echo "Size before: $SIZE_BEFORE"
echo "Size after:  $SIZE_AFTER"
