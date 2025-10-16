#!/bin/bash
# Verify branch structure of all repositories
# Generates a status report for all repos

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Repository Status Verification${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check main repo first
echo -e "${BLUE}Main Repository: openproject-docker-compose${NC}"
echo "----------------------------------------"
echo -e "Current branch: ${YELLOW}$(git branch --show-current)${NC}"
echo "Branches:"
git branch -a | grep -E "(develop|build|main|production)" | sed 's/^/  /'
echo ""

# Check submodules
SUBMODULES=(
    "config-manager"
    "deploy-manager"
    "prober"
    "control-flow"
    "dependency-manager"
    "tui-form-designer"
)

echo -e "${BLUE}Submodule Repositories${NC}"
echo "============================================"
echo ""

for submodule in "${SUBMODULES[@]}"; do
    if [ -d "external/$submodule" ]; then
        echo -e "${BLUE}$submodule${NC}"
        echo "----------------------------------------"
        
        cd "external/$submodule"
        
        if [ -d ".git" ] || [ -f ".git" ]; then
            # Get remote URL
            REMOTE=$(git remote get-url origin 2>/dev/null || echo "No remote")
            echo -e "Remote: $REMOTE"
            
            # Check for each required branch
            echo "Branches:"
            
            # develop
            if git show-ref --verify --quiet refs/remotes/origin/develop || git show-ref --verify --quiet refs/heads/develop; then
                echo -e "  ${GREEN}✓${NC} develop"
            else
                echo -e "  ${RED}✗${NC} develop (missing)"
            fi
            
            # build
            if git show-ref --verify --quiet refs/remotes/origin/build || git show-ref --verify --quiet refs/heads/build; then
                echo -e "  ${GREEN}✓${NC} build"
            else
                echo -e "  ${RED}✗${NC} build (missing)"
            fi
            
            # main/master
            if git show-ref --verify --quiet refs/remotes/origin/main || git show-ref --verify --quiet refs/heads/main; then
                echo -e "  ${GREEN}✓${NC} main"
            elif git show-ref --verify --quiet refs/remotes/origin/master || git show-ref --verify --quiet refs/heads/master; then
                echo -e "  ${GREEN}✓${NC} master"
            else
                echo -e "  ${RED}✗${NC} main/master (missing)"
            fi
            
            # Check for pyproject.toml
            if [ -f "pyproject.toml" ]; then
                VERSION=$(grep -Po '(?<=^version = ")[^"]*' pyproject.toml 2>/dev/null || echo "unknown")
                echo -e "Version: ${GREEN}$VERSION${NC}"
            else
                echo -e "Version: ${YELLOW}No pyproject.toml${NC}"
            fi
            
            # Check for build workflow
            if [ -f ".github/workflows/build-and-release.yml" ] || [ -f ".github/workflows/release.yml" ]; then
                echo -e "Workflow: ${GREEN}✓${NC}"
            else
                echo -e "Workflow: ${YELLOW}Missing${NC}"
            fi
            
        else
            echo -e "${RED}Not a git repository${NC}"
        fi
        
        cd - > /dev/null
    else
        echo -e "${RED}$submodule: Not found${NC}"
    fi
    
    echo ""
done

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Generate summary
TOTAL_REPOS=7  # Main + 6 submodules
CONFIGURED=0
NEEDS_BUILD=0
NEEDS_WORKFLOW=0

# Check main repo
if git show-ref --verify --quiet refs/heads/build && git show-ref --verify --quiet refs/heads/develop; then
    ((CONFIGURED++))
fi

# Check each submodule
for submodule in "${SUBMODULES[@]}"; do
    if [ -d "external/$submodule" ]; then
        cd "external/$submodule"
        
        HAS_DEVELOP=false
        HAS_BUILD=false
        HAS_WORKFLOW=false
        
        if git show-ref --verify --quiet refs/remotes/origin/develop || git show-ref --verify --quiet refs/heads/develop; then
            HAS_DEVELOP=true
        fi
        
        if git show-ref --verify --quiet refs/remotes/origin/build || git show-ref --verify --quiet refs/heads/build; then
            HAS_BUILD=true
        fi
        
        if [ -f ".github/workflows/build-and-release.yml" ] || [ -f ".github/workflows/release.yml" ]; then
            HAS_WORKFLOW=true
        fi
        
        if [ "$HAS_DEVELOP" = true ] && [ "$HAS_BUILD" = true ] && [ "$HAS_WORKFLOW" = true ]; then
            ((CONFIGURED++))
        elif [ "$HAS_DEVELOP" = true ] && [ "$HAS_BUILD" = false ]; then
            ((NEEDS_BUILD++))
        fi
        
        if [ "$HAS_BUILD" = true ] && [ "$HAS_WORKFLOW" = false ]; then
            ((NEEDS_WORKFLOW++))
        fi
        
        cd - > /dev/null
    fi
done

echo "Repository Status:"
echo -e "  ${GREEN}✓ Fully configured: $CONFIGURED / $TOTAL_REPOS${NC}"
if [ $NEEDS_BUILD -gt 0 ]; then
    echo -e "  ${YELLOW}⚠ Need build branch: $NEEDS_BUILD${NC}"
fi
if [ $NEEDS_WORKFLOW -gt 0 ]; then
    echo -e "  ${YELLOW}⚠ Need workflow: $NEEDS_WORKFLOW${NC}"
fi
echo ""

if [ $CONFIGURED -eq $TOTAL_REPOS ]; then
    echo -e "${GREEN}🎉 All repositories fully configured!${NC}"
    echo ""
    echo "Next steps:"
    echo "  - Test releases in one repo"
    echo "  - Roll out to all repos"
    echo "  - Update main repo to use packages"
elif [ $NEEDS_BUILD -gt 0 ]; then
    echo -e "${YELLOW}Action required: Set up build branches${NC}"
    echo ""
    echo "Run: ./scripts/setup_all_build_branches.sh"
elif [ $NEEDS_WORKFLOW -gt 0 ]; then
    echo -e "${YELLOW}Action required: Add build workflows${NC}"
    echo ""
    echo "Run: ./scripts/add_build_workflows_to_all.sh"
else
    echo "Review the details above for specific actions needed."
fi

echo ""
echo "Full report: docs/REPOSITORY_STATUS_REPORT.md"
echo ""
