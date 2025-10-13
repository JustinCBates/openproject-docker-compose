#!/bin/bash
# Branch Restructuring Script
# 
# Transforms repository structure to:
#   - stable/16: Locked upstream reference (never touch)
#   - production: Deployment branch (filtered, clean)
#   - develop: Development branch (full environment)
#
# SAFETY: Creates backup tags before any operations

set -e  # Exit on error

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
MAIN_REPO="/opt/openproject"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Branch Restructuring Script${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Step 1: Create backup tags
echo -e "${GREEN}[Step 1/6] Creating backup tags...${NC}"
echo ""

cd "$MAIN_REPO"
echo "Main repo: Creating backup tag..."
git tag "backup-$TIMESTAMP-feature-python-rebuild"
git push origin "backup-$TIMESTAMP-feature-python-rebuild" || true

echo ""
echo "Submodules: Creating backup tags..."
git submodule foreach "git tag backup-$TIMESTAMP-main && git push origin backup-$TIMESTAMP-main || true"

echo -e "${GREEN}✅ Backup tags created${NC}"
echo ""

# Step 2: Verify current state
echo -e "${GREEN}[Step 2/6] Verifying current state...${NC}"
echo ""

cd "$MAIN_REPO"
CURRENT_BRANCH=$(git branch --show-current)
echo "Main repo current branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" != "feature/python-rebuild" ]; then
    echo -e "${RED}ERROR: Expected to be on feature/python-rebuild, but on $CURRENT_BRANCH${NC}"
    echo "Please checkout feature/python-rebuild first"
    exit 1
fi

# Check remote branches exist
git fetch origin

DEVELOP_EXISTS=$(git branch -r | grep -c "origin/develop" || echo "0")
if [ "$DEVELOP_EXISTS" -eq "0" ]; then
    echo -e "${RED}ERROR: origin/develop not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Current state verified${NC}"
echo ""

# Step 3: Rename origin/develop to origin/production
echo -e "${GREEN}[Step 3/6] Renaming remote branch: origin/develop → origin/production...${NC}"
echo ""

cd "$MAIN_REPO"

# Create production branch from develop
echo "Creating origin/production from origin/develop..."
git push origin origin/develop:refs/heads/production

# Delete old develop branch on remote
echo "Deleting old origin/develop..."
git push origin :develop

echo -e "${GREEN}✅ Remote branch renamed: develop → production${NC}"
echo ""

# Step 4: Rename local branch
echo -e "${GREEN}[Step 4/6] Renaming local branch: feature/python-rebuild → develop...${NC}"
echo ""

cd "$MAIN_REPO"
git branch -m feature/python-rebuild develop

echo -e "${GREEN}✅ Local branch renamed${NC}"
echo ""

# Step 5: Push new develop branch
echo -e "${GREEN}[Step 5/6] Pushing new develop branch to remote...${NC}"
echo ""

cd "$MAIN_REPO"
git push -u origin develop

# Delete old feature/python-rebuild on remote if it exists
echo "Cleaning up old feature/python-rebuild branch..."
git push origin :feature/python-rebuild || true

echo -e "${GREEN}✅ New develop branch pushed${NC}"
echo ""

# Step 6: Update submodules (create develop branches)
echo -e "${GREEN}[Step 6/6] Creating develop branches in submodules...${NC}"
echo ""

SUBMODULES=(
    "external/config-manager"
    "external/control-flow"
    "external/deploy-manager"
    "external/dependency-manager"
    "external/prober"
    "external/tui-form-designer"
)

for submodule in "${SUBMODULES[@]}"; do
    echo ""
    echo -e "${BLUE}Processing: $submodule${NC}"
    cd "$MAIN_REPO/$submodule"
    
    # Ensure we're on main
    git checkout main 2>/dev/null || git checkout master 2>/dev/null || true
    
    # Create develop branch from current main
    if git branch | grep -q "develop"; then
        echo "  develop branch already exists, skipping..."
    else
        echo "  Creating develop branch..."
        git checkout -b develop
        git push -u origin develop
        git checkout main  # Switch back to main
    fi
    
    echo -e "  ${GREEN}✅ Done${NC}"
done

cd "$MAIN_REPO"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}✅ Branch restructuring complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

echo -e "${BLUE}Current structure:${NC}"
echo ""
echo "Main repo:"
echo "  - stable/16: Locked upstream reference"
echo "  - production: Deployment branch (was develop)"
echo "  - develop: Development branch (was feature/python-rebuild)"
echo ""
echo "Submodules (each has):"
echo "  - main: Current production code"
echo "  - develop: Development branch (newly created)"
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo "1. Create filtered 'production' branches in submodules:"
echo "   cd /opt/openproject"
echo "   python3 external/dependency-manager/tools/setup_production_branch.py init --target-branch production --source-branch develop"
echo ""
echo "2. Update .gitmodules to track correct branches"
echo ""
echo "3. Test branch switching:"
echo "   ./scripts/switch-branch.sh develop"
echo "   ./scripts/switch-branch.sh production"
echo ""

echo -e "${BLUE}Backup tags created:${NC}"
echo "  Main: backup-$TIMESTAMP-feature-python-rebuild"
echo "  Submodules: backup-$TIMESTAMP-main"
echo ""
echo "To restore if needed:"
echo "  git checkout backup-$TIMESTAMP-feature-python-rebuild"
echo "  git branch -m feature/python-rebuild"
