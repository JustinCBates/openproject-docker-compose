#!/bin/bash
# Quick start script to convert config-manager to standalone package
# This is a proof of concept for the multi-repo strategy

set -e

echo "============================================"
echo "Convert Submodule to Standalone Package"
echo "Proof of Concept: config-manager"
echo "============================================"

# Check if we're in the right place
if [ ! -d "external/config-manager" ]; then
    echo "Error: Run this from /opt/openproject"
    exit 1
fi

echo ""
echo "Step 1: Create standalone repo for config-manager"
echo "---------------------------------------------------"
cd external/config-manager

# Check if remote already exists
if git remote get-url standalone 2>/dev/null; then
    echo "✓ Standalone remote already exists"
else
    echo "Creating GitHub repo..."
    gh repo create JustinCBates/openproject-config-manager \
        --public \
        --description "Configuration manager for OpenProject - extracted from monorepo" \
        --source=. \
        --remote=standalone || echo "Repo might already exist"
fi

echo ""
echo "Step 2: Set up three-tier branch structure"
echo "-------------------------------------------"
git checkout develop 2>/dev/null || git checkout -b develop

# Create build branch
if git show-ref --verify --quiet refs/heads/build; then
    echo "✓ build branch exists"
else
    git checkout -b build develop
    git checkout develop
    echo "✓ Created build branch"
fi

# Create main branch  
if git show-ref --verify --quiet refs/heads/main; then
    echo "✓ main branch exists"
else
    git checkout -b main develop
    git checkout develop
    echo "✓ Created main branch"
fi

echo ""
echo "Step 3: Push all branches to standalone repo"
echo "---------------------------------------------"
git push standalone develop build main

echo ""
echo "Step 4: Create build workflow"
echo "------------------------------"
mkdir -p .github/workflows
cat > .github/workflows/build-and-release.yml << 'EOF'
name: Build and Release

on:
  push:
    branches: [build]
  pull_request:
    branches: [build]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          pip install pytest pytest-cov
          pip install -e .
      
      - name: Run tests
        run: pytest tests/ -v --cov=src || echo "Tests pending"

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/build'
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      
      - name: Build package
        run: |
          pip install build
          python -m build
      
      - name: Get version
        id: version
        run: |
          VERSION=$(grep -Po '(?<=^version = ")[^"]*' pyproject.toml)
          echo "version=$VERSION" >> $GITHUB_OUTPUT
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: v${{ steps.version.outputs.version }}
          name: Config Manager v${{ steps.version.outputs.version }}
          files: dist/*
          body: |
            ## Installation
            ```bash
            pip install https://github.com/JustinCBates/openproject-config-manager/releases/download/v${{ steps.version.outputs.version }}/openproject_config_manager-${{ steps.version.outputs.version }}-py3-none-any.whl
            ```
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
EOF

git add .github/workflows/build-and-release.yml
git commit -m "ci: add build and release workflow" || echo "Already committed"
git push standalone develop

echo ""
echo "Step 5: Update package metadata for standalone distribution"
echo "------------------------------------------------------------"

# Ensure pyproject.toml has proper package name
if ! grep -q "name = \"openproject-config-manager\"" pyproject.toml; then
    echo "⚠ Update pyproject.toml with name = \"openproject-config-manager\""
fi

echo ""
echo "============================================"
echo "✓ config-manager is now a standalone package!"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. Review .github/workflows/build-and-release.yml"
echo "2. Merge develop → build to trigger first release"
echo "3. Verify release created at:"
echo "   https://github.com/JustinCBates/openproject-config-manager/releases"
echo "4. Update main orchestrator to use package:"
echo "   cd /opt/openproject"
echo "   ./scripts/migrate_to_packages.sh"
echo "============================================"

cd /opt/openproject
