#!/bin/bash
# Setup and verify the build branch

set -e

echo "============================================"
echo "Build Branch Setup & Verification"
echo "============================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo -e "${YELLOW}Current branch: $CURRENT_BRANCH${NC}"
echo ""

# Verify build branch exists
if git show-ref --verify --quiet refs/heads/build; then
    echo -e "${GREEN}✓ Build branch exists locally${NC}"
else
    echo -e "${RED}✗ Build branch does not exist locally${NC}"
    echo "Creating build branch from develop..."
    git checkout develop
    git checkout -b build
    echo -e "${GREEN}✓ Build branch created${NC}"
fi

# Check remote tracking
if git config --get branch.build.remote > /dev/null; then
    REMOTE=$(git config --get branch.build.remote)
    echo -e "${GREEN}✓ Build branch tracks remote: $REMOTE${NC}"
else
    echo -e "${YELLOW}⚠ Build branch not tracking remote${NC}"
    read -p "Set up remote tracking? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git checkout build
        git push -u origin build
        echo -e "${GREEN}✓ Remote tracking set up${NC}"
    fi
fi

# Check if build branch is up to date with origin
git fetch origin build 2>/dev/null || true
LOCAL=$(git rev-parse build 2>/dev/null || echo "")
REMOTE=$(git rev-parse origin/build 2>/dev/null || echo "")

if [ "$LOCAL" = "$REMOTE" ]; then
    echo -e "${GREEN}✓ Build branch is up to date with origin${NC}"
elif [ -z "$REMOTE" ]; then
    echo -e "${YELLOW}⚠ Build branch not pushed to origin yet${NC}"
else
    echo -e "${YELLOW}⚠ Build branch differs from origin${NC}"
    echo "  Local:  $LOCAL"
    echo "  Remote: $REMOTE"
fi

echo ""
echo "============================================"
echo "Branch Structure"
echo "============================================"
echo ""

# Show branch structure
git branch -a | grep -E "(develop|build|main|production)" || true

echo ""
echo "============================================"
echo "Build Branch Checklist"
echo "============================================"
echo ""

# Check for essential files
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1 (missing)"
    fi
}

check_file "pyproject.toml"
check_file ".github/workflows/build-and-release.yml"
check_file "scripts/build_package.sh"
check_file "README_BUILD_BRANCH.md"
check_file "LICENSE"

echo ""
echo "============================================"
echo "Version Information"
echo "============================================"
echo ""

if [ -f "pyproject.toml" ]; then
    VERSION=$(grep -Po '(?<=^version = ")[^"]*' pyproject.toml 2>/dev/null || echo "unknown")
    echo -e "Current version: ${GREEN}$VERSION${NC}"
else
    echo -e "${RED}pyproject.toml not found${NC}"
fi

echo ""
echo "============================================"
echo "Recent Commits on Build Branch"
echo "============================================"
echo ""

git log --oneline --graph --decorate -5 build 2>/dev/null || echo "No commits yet"

echo ""
echo "============================================"
echo "Next Steps"
echo "============================================"
echo ""

if [ "$CURRENT_BRANCH" != "build" ]; then
    echo "1. Switch to build branch:"
    echo "   git checkout build"
    echo ""
fi

echo "2. To create a release:"
echo "   a. Switch to develop and bump version"
echo "      git checkout develop"
echo "      # Edit pyproject.toml version"
echo "      git commit -m 'chore: bump version to X.Y.Z'"
echo "      git push origin develop"
echo ""
echo "   b. Create PR from develop to build"
echo "      gh pr create --base build --title 'Release vX.Y.Z'"
echo ""
echo "   c. Merge PR (triggers GitHub Actions to build & release)"
echo "      gh pr merge --merge"
echo ""

echo "3. To test build locally:"
echo "   ./scripts/build_package.sh"
echo ""

echo "4. View releases:"
echo "   gh release list"
echo "   # or visit: https://github.com/JustinCBates/openproject-docker-compose/releases"
echo ""

echo "============================================"
echo "Documentation"
echo "============================================"
echo ""
echo "Read more:"
echo "- README_BUILD_BRANCH.md"
echo "- docs/MULTI_REPO_STRATEGY.md"
echo "- docs/QUICK_REFERENCE.md"
echo ""

echo -e "${GREEN}Setup verification complete!${NC}"
