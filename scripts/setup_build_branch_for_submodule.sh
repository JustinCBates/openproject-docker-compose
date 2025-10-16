#!/bin/bash
# Setup build branch for a single submodule repository
# Usage: ./setup_build_branch_for_submodule.sh <submodule-name>

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ -z "$1" ]; then
    echo -e "${RED}Error: Submodule name required${NC}"
    echo "Usage: $0 <submodule-name>"
    echo ""
    echo "Available submodules:"
    ls -1 external/ | grep -v phases
    exit 1
fi

SUBMODULE=$1
SUBMODULE_PATH="external/$SUBMODULE"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Setup Build Branch for: $SUBMODULE${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check if submodule exists
if [ ! -d "$SUBMODULE_PATH" ]; then
    echo -e "${RED}Error: Submodule not found: $SUBMODULE_PATH${NC}"
    exit 1
fi

cd "$SUBMODULE_PATH"

# Verify it's a git repo
if [ ! -d ".git" ] && [ ! -f ".git" ]; then
    echo -e "${RED}Error: Not a git repository${NC}"
    exit 1
fi

echo -e "${YELLOW}Current directory: $(pwd)${NC}"
echo ""

# Get remote URL
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "unknown")
echo -e "Remote URL: ${GREEN}$REMOTE_URL${NC}"
echo ""

# Check current branch
CURRENT_BRANCH=$(git branch --show-current || echo "detached")
echo -e "Current branch: ${GREEN}$CURRENT_BRANCH${NC}"
echo ""

# Fetch latest
echo -e "${YELLOW}Fetching latest from remote...${NC}"
git fetch origin

# Check if build branch already exists
if git show-ref --verify --quiet refs/remotes/origin/build; then
    echo -e "${GREEN}✓ Build branch already exists on remote${NC}"
    echo ""
    read -p "Recreate build branch? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping..."
        exit 0
    fi
fi

# Make sure we're on develop
echo -e "${YELLOW}Switching to develop branch...${NC}"
if git show-ref --verify --quiet refs/heads/develop; then
    git checkout develop
elif git show-ref --verify --quiet refs/remotes/origin/develop; then
    git checkout -b develop origin/develop
else
    echo -e "${RED}Error: No develop branch found${NC}"
    exit 1
fi

git pull origin develop
echo -e "${GREEN}✓ On develop branch, up to date${NC}"
echo ""

# Create build branch
echo -e "${YELLOW}Creating build branch...${NC}"
if git show-ref --verify --quiet refs/heads/build; then
    git branch -D build
fi

git checkout -b build develop
echo -e "${GREEN}✓ Build branch created from develop${NC}"
echo ""

# Check for pyproject.toml
if [ -f "pyproject.toml" ]; then
    VERSION=$(grep -Po '(?<=^version = ")[^"]*' pyproject.toml 2>/dev/null || echo "unknown")
    echo -e "Package version: ${GREEN}$VERSION${NC}"
else
    echo -e "${YELLOW}⚠ No pyproject.toml found${NC}"
    echo "You may need to add one for proper packaging"
fi
echo ""

# Push build branch
echo -e "${YELLOW}Pushing build branch to origin...${NC}"
git push -u origin build
echo -e "${GREEN}✓ Build branch pushed to remote${NC}"
echo ""

# Switch back to develop
git checkout develop
echo -e "${GREEN}✓ Switched back to develop${NC}"
echo ""

echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}✓ Build branch setup complete for: $SUBMODULE${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

echo "Next steps:"
echo "1. Add build workflow:"
echo "   cd $SUBMODULE_PATH"
echo "   mkdir -p .github/workflows"
echo "   # Copy build-and-release.yml from main repo"
echo ""
echo "2. Test the build:"
echo "   git checkout build"
echo "   python -m build"
echo ""
echo "3. Create first release:"
echo "   # Bump version on develop"
echo "   # Create PR: develop → build"
echo "   # Merge to trigger automated build"
echo ""

cd - > /dev/null
