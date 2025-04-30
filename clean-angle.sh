#!/bin/bash

# Define directories to clean
ANGLE_DIR="angle"
DEPOT_TOOLS_DIR="depot_tools"
BUILD_DIR="build"

# Function to safely remove directories if they exist
remove_if_exists() {
    if [ -d "$1" ]; then
        echo "Removing $1 directory..."
        rm -rf "$1"
    else
        echo "$1 directory does not exist, skipping."
    fi
}

# Main cleanup
echo "Starting cleanup..."
remove_if_exists "$ANGLE_DIR"
remove_if_exists "$DEPOT_TOOLS_DIR"
remove_if_exists "$BUILD_DIR"
echo "Cleanup complete."
