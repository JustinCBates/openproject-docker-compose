#!/bin/bash
# Setup build branches for all submodule repositories
# This script automates the process for all submodules

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Setup Build Branches for All Submodules${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# List of submodules (excluding 'phases' which isn't a git repo)
SUBMODULES=(
    "config-manager"
    "deploy-manager"
    "prober"
    "control-flow"
    "dependency-manager"
    "tui-form-designer"
)

echo "Submodules to process:"
for submodule in "${SUBMODULES[@]}"; do
    echo "  - $submodule"
done
echo ""

read -p "Continue with setup for all submodules? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""

# Counter for tracking
TOTAL=${#SUBMODULES[@]}
SUCCESS=0
FAILED=0
SKIPPED=0

# Process each submodule
for submodule in "${SUBMODULES[@]}"; do
    echo -e "${BLUE}----------------------------------------${NC}"
    echo -e "${BLUE}Processing: $submodule ($(($SUCCESS + $FAILED + $SKIPPED + 1))/$TOTAL)${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    echo ""
    
    if [ ! -d "external/$submodule" ]; then
        echo -e "${RED}✗ Submodule not found: external/$submodule${NC}"
        ((FAILED++))
        echo ""
        continue
    fi
    
    # Run the setup script for this submodule
    if ./scripts/setup_build_branch_for_submodule.sh "$submodule"; then
        echo -e "${GREEN}✓ Successfully set up build branch for: $submodule${NC}"
        ((SUCCESS++))
    else
        echo -e "${RED}✗ Failed to set up build branch for: $submodule${NC}"
        ((FAILED++))
    fi
    
    echo ""
    sleep 1  # Brief pause between repos
done

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Setup Complete${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

echo "Results:"
echo -e "  ${GREEN}✓ Success: $SUCCESS${NC}"
echo -e "  ${RED}✗ Failed:  $FAILED${NC}"
echo -e "  ${YELLOW}⊘ Skipped: $SKIPPED${NC}"
echo -e "  Total:     $TOTAL"
echo ""

if [ $SUCCESS -eq $TOTAL ]; then
    echo -e "${GREEN}🎉 All submodules configured successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Add build workflows to each repository"
    echo "   Run: ./scripts/add_build_workflows_to_all.sh"
    echo ""
    echo "2. Test one repository:"
    echo "   cd external/config-manager"
    echo "   git checkout build"
    echo "   python -m build"
    echo ""
    echo "3. Create releases:"
    echo "   For each repo, create PR: develop → build"
    echo "   Merge will trigger automated builds"
    echo ""
elif [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}Setup completed with some skips.${NC}"
    echo "Review the output above for details."
else
    echo -e "${YELLOW}Setup completed with some failures.${NC}"
    echo "Review the output above and manually fix failed repositories."
fi

echo ""
echo "To verify all repositories:"
echo "  ./scripts/verify_all_repos.sh"
echo ""
