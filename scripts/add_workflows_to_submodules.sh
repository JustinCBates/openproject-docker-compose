#!/bin/bash

# Script to add GitHub Actions build workflows to all submodules
# This enables automated building and releasing when code is merged to build branch

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Submodules to process
SUBMODULES=(
    "config-manager:openproject-config-manager:Config Manager"
    "deploy-manager:openproject-deploy-manager:Deploy Manager"
    "prober:docker-prober-utility:Docker Prober Utility"
    "control-flow:control-flow:Control Flow"
    "dependency-manager:dependency-manager:Dependency Manager"
    "tui-form-designer:tui-form-designer:TUI Form Designer"
)

echo "============================================"
echo "Add GitHub Actions Workflows to Submodules"
echo "============================================"
echo ""

# Track results
SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_REPOS=()

for entry in "${SUBMODULES[@]}"; do
    IFS=':' read -r REPO_DIR PACKAGE_NAME DISPLAY_NAME <<< "$entry"
    
    echo -e "${BLUE}----------------------------------------${NC}"
    echo -e "${BLUE}Processing: $DISPLAY_NAME ($REPO_DIR)${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    echo ""
    
    REPO_PATH="external/$REPO_DIR"
    
    # Check if repo exists
    if [ ! -d "$REPO_PATH" ]; then
        echo -e "${RED}✗ Repository not found: $REPO_PATH${NC}"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_REPOS+=("$REPO_DIR")
        echo ""
        continue
    fi
    
    cd "$REPO_PATH"
    
    # Get current branch
    CURRENT_BRANCH=$(git branch --show-current)
    echo "Current branch: $CURRENT_BRANCH"
    
    # Switch to build branch
    echo "Switching to build branch..."
    git fetch --all
    git checkout build
    git pull
    
    # Create .github/workflows directory
    echo "Creating .github/workflows directory..."
    mkdir -p .github/workflows
    
    # Create workflow file
    WORKFLOW_FILE=".github/workflows/build-and-release.yml"
    echo "Creating $WORKFLOW_FILE..."
    
    cat > "$WORKFLOW_FILE" << 'WORKFLOW_EOF'
name: Build and Release

on:
  push:
    branches:
      - build
  pull_request:
    branches:
      - build

jobs:
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install pytest pytest-cov
          if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
          pip install -e .
      
      - name: Run tests
        run: |
          if [ -d tests ]; then
            pytest tests/ -v --cov=src --cov-report=term-missing
          else
            echo "No tests directory found, skipping tests"
          fi

  build:
    name: Build Distribution
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/build'
    
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      
      - name: Install build tools
        run: |
          python -m pip install --upgrade pip
          pip install build twine
      
      - name: Build wheel and sdist
        run: |
          python -m build
      
      - name: Check distribution
        run: |
          twine check dist/*
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: distribution
          path: dist/
      
      - name: Generate version
        id: version
        run: |
          # Extract version from pyproject.toml
          if [ -f pyproject.toml ]; then
            VERSION=$(grep -Po '(?<=^version = ")[^"]*' pyproject.toml)
          else
            VERSION="0.1.0"
          fi
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "Building version: $VERSION"
      
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: v${{ steps.version.outputs.version }}
          name: PACKAGE_NAME_PLACEHOLDER v${{ steps.version.outputs.version }}
          body: |
            ## PACKAGE_NAME_PLACEHOLDER v${{ steps.version.outputs.version }}
            
            ### Installation
            ```bash
            pip install https://github.com/${{ github.repository }}/releases/download/v${{ steps.version.outputs.version }}/PACKAGE_FILENAME_PLACEHOLDER-${{ steps.version.outputs.version }}-py3-none-any.whl
            ```
            
            Or download the wheel and install locally:
            ```bash
            wget https://github.com/${{ github.repository }}/releases/download/v${{ steps.version.outputs.version }}/PACKAGE_FILENAME_PLACEHOLDER-${{ steps.version.outputs.version }}-py3-none-any.whl
            pip install PACKAGE_FILENAME_PLACEHOLDER-${{ steps.version.outputs.version }}-py3-none-any.whl
            ```
            
            ### What's Included
            - PACKAGE_NAME_PLACEHOLDER package
            - All dependencies
            - Documentation
            
            ### Documentation
            See [README.md](https://github.com/${{ github.repository }}/blob/develop/README.md)
          files: |
            dist/*.whl
            dist/*.tar.gz
          draft: false
          prerelease: false
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  cleanup:
    name: Clean Build Branch
    needs: build
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/build'
    
    steps:
      - uses: actions/checkout@v4
        with:
          ref: build
          token: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Remove development files
        run: |
          # Keep only essential files for production reference
          git rm -rf tests/ || true
          git rm -rf docs/ || true
          git rm -rf .pytest_cache/ || true
          
          # Create minimal README for build branch
          cat > README.md << 'EOF'
          # PACKAGE_NAME_PLACEHOLDER - Build Branch
          
          This branch contains build automation and release artifacts.
          
          ## Installation
          
          Install the latest release:
          ```bash
          pip install PACKAGE_FILENAME_PLACEHOLDER
          ```
          
          Or download from [Releases](https://github.com/${{ github.repository }}/releases).
          
          ## Development
          
          For development, see the [develop branch](https://github.com/${{ github.repository }}/tree/develop).
          EOF
          
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add README.md
          git commit -m "chore: cleanup build branch after release" || true
          git push origin build || true
WORKFLOW_EOF
    
    # Replace placeholders with actual package names
    sed -i "s/PACKAGE_NAME_PLACEHOLDER/$DISPLAY_NAME/g" "$WORKFLOW_FILE"
    sed -i "s/PACKAGE_FILENAME_PLACEHOLDER/$PACKAGE_NAME/g" "$WORKFLOW_FILE"
    
    echo -e "${GREEN}✓ Workflow file created${NC}"
    
    # Check if there are changes (staged, unstaged, or untracked)
    git add .github/
    if git diff --cached --quiet; then
        echo -e "${YELLOW}! Workflow file already exists and is up to date${NC}"
    else
        # Commit
        git commit -m "ci: add GitHub Actions build and release workflow"
        echo -e "${GREEN}✓ Workflow file committed${NC}"
        
        # Push to remote
        git push origin build
        echo -e "${GREEN}✓ Pushed to origin/build${NC}"
    fi
    
    # Switch back to original branch
    git checkout "$CURRENT_BRANCH"
    echo -e "${GREEN}✓ Switched back to $CURRENT_BRANCH${NC}"
    
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    
    # Return to main repo
    cd /opt/openproject
    echo ""
done

echo "============================================"
echo "Summary"
echo "============================================"
echo ""
echo -e "${GREEN}✓ Successfully processed: $SUCCESS_COUNT${NC}"
echo -e "${RED}✗ Failed: $FAILED_COUNT${NC}"

if [ $FAILED_COUNT -gt 0 ]; then
    echo ""
    echo "Failed repositories:"
    for repo in "${FAILED_REPOS[@]}"; do
        echo "  - $repo"
    done
fi

echo ""
echo "============================================"
echo "Next Steps"
echo "============================================"
echo ""
echo "1. Verify workflows were added:"
echo "   ./scripts/verify_all_repos.sh"
echo ""
echo "2. Test one repository:"
echo "   - Bump version on develop branch"
echo "   - Create PR: develop → build"
echo "   - Merge and watch GitHub Actions"
echo "   - Verify release is created"
echo ""
echo "3. Once tested, roll out to remaining repos"
echo ""

if [ $SUCCESS_COUNT -eq ${#SUBMODULES[@]} ]; then
    echo -e "${GREEN}✓ All workflows added successfully!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some repositories had issues${NC}"
    exit 1
fi
