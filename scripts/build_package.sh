#!/bin/bash
# Build script for creating distribution packages
# This runs locally or in CI to create wheel and source distributions

set -e

echo "============================================"
echo "OpenProject Orchestrator - Build Script"
echo "============================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "pyproject.toml" ]; then
    echo -e "${RED}Error: pyproject.toml not found${NC}"
    echo "Please run this script from the project root"
    exit 1
fi

# Extract version
VERSION=$(grep -Po '(?<=^version = ")[^"]*' pyproject.toml)
echo -e "${GREEN}Building version: $VERSION${NC}"

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf dist/ build/ *.egg-info src/*.egg-info

# Install build tools
echo -e "${YELLOW}Installing build tools...${NC}"
pip install --upgrade build twine

# Run tests first
echo -e "${YELLOW}Running tests...${NC}"
if command -v pytest &> /dev/null; then
    pytest tests/ -v --cov=src --cov-report=term-missing || {
        echo -e "${RED}Tests failed! Aborting build.${NC}"
        exit 1
    }
else
    echo -e "${YELLOW}pytest not found, skipping tests${NC}"
fi

# Build distributions
echo -e "${YELLOW}Building wheel and source distribution...${NC}"
python -m build

# Check distributions
echo -e "${YELLOW}Checking distribution packages...${NC}"
twine check dist/*

# List built files
echo -e "${GREEN}Build complete!${NC}"
echo ""
echo "Built packages:"
ls -lh dist/

echo ""
echo "============================================"
echo "Next steps:"
echo "1. Test the wheel locally:"
echo "   pip install dist/openproject_orchestrator-${VERSION}-py3-none-any.whl"
echo ""
echo "2. Upload to PyPI (if configured):"
echo "   twine upload dist/*"
echo ""
echo "3. Create GitHub release:"
echo "   gh release create v${VERSION} dist/* --title 'v${VERSION}' --notes 'Release notes here'"
echo "============================================"
