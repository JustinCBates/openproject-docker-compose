#!/bin/bash

# Git User Configuration Utility Script
# Sets git username and email based on variables from deploy_interactive.cfg

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../deploy_interactive.cfg"

echo "=========================================="
echo "Git User Configuration Utility"
echo "=========================================="

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    echo "Please run the interactive deployment script first."
    exit 1
fi

# Load configuration variables
echo "Loading configuration from $CONFIG_FILE..."
source "$CONFIG_FILE"

# Validate that git variables exist
if [ -z "$GIT_USERNAME" ] && [ -z "$GIT_EMAIL" ]; then
    echo "No git configuration found in $CONFIG_FILE"
    echo "Skipping git user configuration."
    exit 0
fi

echo "Configuring git user settings..."

# Set git username if provided
if [ -n "$GIT_USERNAME" ]; then
    echo "Setting git username to: $GIT_USERNAME"
    git config --global user.name "$GIT_USERNAME"
    echo "✓ Git username configured"
else
    echo "⚠ No git username specified, skipping"
fi

# Set git email if provided
if [ -n "$GIT_EMAIL" ]; then
    echo "Setting git email to: $GIT_EMAIL"
    git config --global user.email "$GIT_EMAIL"
    echo "✓ Git email configured"
else
    echo "⚠ No git email specified, skipping"
fi

echo
echo "Current git configuration:"
echo "-------------------------"
echo "Username: $(git config --global user.name 2>/dev/null || echo 'Not set')"
echo "Email:    $(git config --global user.email 2>/dev/null || echo 'Not set')"

echo
