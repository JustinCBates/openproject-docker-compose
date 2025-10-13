#!/bin/bash
# Quick production branch creator for submodules
# Filters out dev-only files based on patterns

set -e

REPO_PATH="$1"
if [ -z "$REPO_PATH" ]; then
    echo "Usage: $0 <repo-path>"
    exit 1
fi

cd "$REPO_PATH"
REPO_NAME=$(basename "$REPO_PATH")

echo "Creating production branch for $REPO_NAME..."

# Ensure we're on develop
git checkout develop

# Check if production already exists
if git branch | grep -q "production"; then
    echo "  production branch already exists, deleting..."
    git branch -D production
fi

# Create production branch
git checkout -b production

# Remove development-only files
echo "  Filtering development files..."

# Remove test directories
git rm -rf testing/ tests/ test/ 2>/dev/null || true
git rm -f test_*.py *_test.py 2>/dev/null || true

# Remove documentation
git rm -rf docs/ documents/ design_specs/ 2>/dev/null || true
git rm -f *.md 2>/dev/null || echo "  (keeping some .md files)"
git restore --staged README.md LICENSE.md 2>/dev/null || true

# Remove development scripts
git rm -f demo_*.py example_*.py 2>/dev/null || true

# Remove build artifacts
git rm -rf __pycache__/ .pytest_cache/ *.egg-info/ dist/ build/ 2>/dev/null || true
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true

# Remove git/editor configs
git rm -rf .github/ .vscode/ .idea/ 2>/dev/null || true
git rm -f .gitignore .flake8 2>/dev/null || true

# Remove migration backups
git rm -rf migration_backup/ 2>/dev/null || true

# Commit if there are changes
if git diff --cached --quiet; then
    echo "  No files to remove, production = develop"
else
    git commit -m "chore: create production branch (remove dev-only files)"
    echo "  ✅ Production branch created"
fi

# Push to remote
echo "  Pushing to origin/production..."
git push -u origin production

# Switch back to develop
git checkout develop

echo "✅ Done: $REPO_NAME"
