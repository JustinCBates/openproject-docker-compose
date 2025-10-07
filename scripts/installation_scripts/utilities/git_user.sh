#!/bin/bash#!/bin/bash



# Git User Configuration Utility Script# Git User Configuration Utility Script

# Sets git username and email based on variables from deploy_interactive.cfg# Sets git username and email based on variables from .deploy_interactive.cfg



set -e  # Exit on any errorset -e  # Exit on any error



SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

CONFIG_FILE="$SCRIPT_DIR/../deploy_interactive.cfg"CONFIG_FILE="$SCRIPT_DIR/../deploy_interactive.cfg"



echo "=========================================="echo "=========================================="

echo "Git User Configuration Utility"echo "Git User Configuration Utility"

echo "=========================================="echo "=========================================="



# Check if configuration file exists# Check if configuration file exists

if [ ! -f "$CONFIG_FILE" ]; thenif [ ! -f "$CONFIG_FILE" ]; then

    echo "Error: Configuration file not found at $CONFIG_FILE"    echo "Error: Configuration file not found at $CONFIG_FILE"

    echo "Please run the interactive deployment script first."    echo "Please run the interactive deployment script first."

    exit 1    exit 1

fifi



# Load configuration variables# Load configuration variables

echo "Loading configuration from $CONFIG_FILE..."echo "Loading configuration from $CONFIG_FILE..."

source "$CONFIG_FILE"source "$CONFIG_FILE"



# Validate that git variables exist# Validate that git variables exist

if [ -z "$GIT_USERNAME" ] && [ -z "$GIT_EMAIL" ]; thenif [ -z "$GIT_USERNAME" ] && [ -z "$GIT_EMAIL" ]; then

    echo "No git configuration found in $CONFIG_FILE"    echo "No git configuration found in $CONFIG_FILE"

    echo "Skipping git user configuration."    echo "Skipping git user configuration."

    exit 0    exit 0

fifi



echo "Configuring git user settings..."echo "Configuring git user settings..."



# Set git username if provided# Set git username if provided

if [ -n "$GIT_USERNAME" ]; thenif [ -n "$GIT_USERNAME" ]; then

    echo "Setting git username to: $GIT_USERNAME"    echo "Setting git username to: $GIT_USERNAME"

    git config --global user.name "$GIT_USERNAME"    git config --global user.name "$GIT_USERNAME"

    echo "✓ Git username configured"    echo "✓ Git username configured"

elseelse

    echo "⚠ No git username specified, skipping"    echo "⚠ No git username specified, skipping"

fifi



# Set git email if provided# Set git email if provided

if [ -n "$GIT_EMAIL" ]; thenif [ -n "$GIT_EMAIL" ]; then

    echo "Setting git email to: $GIT_EMAIL"    echo "Setting git email to: $GIT_EMAIL"

    git config --global user.email "$GIT_EMAIL"    git config --global user.email "$GIT_EMAIL"

    echo "✓ Git email configured"    echo "✓ Git email configured"

elseelse

    echo "⚠ No git email specified, skipping"    echo "⚠ No git email specified, skipping"

fifi



echoecho

echo "Current git configuration:"echo "Current git configuration:"

echo "-------------------------"echo "-------------------------"

echo "Username: $(git config --global user.name 2>/dev/null || echo 'Not set')"echo "Username: $(git config --global user.name 2>/dev/null || echo 'Not set')"

echo "Email:    $(git config --global user.email 2>/dev/null || echo 'Not set')"echo "Email:    $(git config --global user.email 2>/dev/null || echo 'Not set')"



echoecho
echo "Git user configuration completed!"