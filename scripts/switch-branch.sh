#!/bin/bash
# Switch branch helper - manages parent + submodule branch synchronization
#
# Usage:
#   ./scripts/switch-branch.sh develop   # Switch to development environment
#   ./scripts/switch-branch.sh main      # Switch to production environment

set -e

BRANCH=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ -z "$BRANCH" ]; then
    echo -e "${RED}Error: Branch name required${NC}"
    echo "Usage: $0 {main|develop}"
    exit 1
fi

if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "develop" ]; then
    echo -e "${YELLOW}Warning: Expected 'main' or 'develop', got '$BRANCH'${NC}"
    echo "Continuing anyway..."
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Switching to '$BRANCH' branch${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Switch parent repo
echo -e "${GREEN}[1/4] Switching parent repository...${NC}"
cd "$REPO_ROOT"
git checkout "$BRANCH"
echo -e "   Parent: $(git branch --show-current)"
echo ""

# Step 2: Update .gitmodules branch tracking
echo -e "${GREEN}[2/4] Checking .gitmodules configuration...${NC}"
# Check if .gitmodules specifies correct branch
EXPECTED_BRANCH_COUNT=$(grep -c "branch = $BRANCH" .gitmodules 2>/dev/null || echo "0")
TOTAL_SUBMODULES=$(grep -c '^\[submodule' .gitmodules)

if [ "$EXPECTED_BRANCH_COUNT" -eq "$TOTAL_SUBMODULES" ]; then
    echo -e "   ✅ .gitmodules correctly configured for $BRANCH"
else
    echo -e "   ${YELLOW}⚠️  .gitmodules may need updating${NC}"
    echo -e "   Expected all submodules to track '$BRANCH' branch"
    echo -e "   Found $EXPECTED_BRANCH_COUNT/$TOTAL_SUBMODULES correct"
fi
echo ""

# Step 3: Initialize/update submodules
echo -e "${GREEN}[3/4] Updating submodules to tracked branches...${NC}"
git submodule update --init --recursive --remote
echo ""

# Step 4: Show status
echo -e "${GREEN}[4/4] Verifying submodule branches...${NC}"
echo -e "${BLUE}Current branch status:${NC}"
echo -e "   Parent: ${GREEN}$(git branch --show-current)${NC}"
echo ""
echo -e "   Submodules:"

git submodule foreach --quiet 'printf "     %-25s %s\n" "$name:" "$(git branch --show-current)"'

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Successfully switched to '$BRANCH'${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Provide guidance based on branch
if [ "$BRANCH" = "develop" ]; then
    echo -e "${BLUE}Development Environment Ready${NC}"
    echo -e "  - Full tooling, tests, and documentation available"
    echo -e "  - Make changes and commit to develop"
    echo -e "  - Run tests: pytest tests/"
elif [ "$BRANCH" = "main" ]; then
    echo -e "${BLUE}Production Environment Active${NC}"
    echo -e "  - Minimal, deployment-ready code only"
    echo -e "  - No dev tools or test files"
    echo -e "  - Deploy with: docker-compose up -d"
fi
