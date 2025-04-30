#!/bin/bash
set -e

# Configure commits
ANGLE_COMMIT="f6da7aed210035a54e406ada571fb34892092c24"
DEPOT_TOOLS_COMMIT="43d3eba89bc6b4fe34d99f0ee4af0ccc291c528c"

# Check if homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed. Please install it first:"
    echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# Install ninja if not available
if ! command -v ninja &> /dev/null; then
    echo "Installing ninja..."
    brew install ninja
fi

# Get current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Clone or update depot_tools
if [ ! -d "depot_tools" ]; then
    echo "Cloning depot_tools..."
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
    cd depot_tools
    git checkout $DEPOT_TOOLS_COMMIT
    cd ..
else
    echo "depot_tools directory already exists, checking out specific commit..."
    cd depot_tools
    git fetch
    git checkout $DEPOT_TOOLS_COMMIT
    cd ..
fi

# Add depot_tools to PATH
export PATH="$PATH:$SCRIPT_DIR/depot_tools"

# Clone or update ANGLE
if [ ! -d "angle" ]; then
    echo "Cloning ANGLE repository..."
    git clone https://chromium.googlesource.com/angle/angle
    cd angle
    git checkout $ANGLE_COMMIT
    cd ..
else
    echo "ANGLE directory already exists, checking out specific commit..."
    cd angle
    git fetch
    git checkout $ANGLE_COMMIT
    cd ..
fi

# Configure and sync ANGLE dependencies
cd angle
echo "Configuring gclient..."
gclient config --unmanaged https://chromium.googlesource.com/angle/angle

# Create a .gclient file with proper setup
cat > .gclient << EOL
solutions = [
  {
    "name": ".",
    "url": "https://chromium.googlesource.com/angle/angle",
    "deps_file": "DEPS",
    "managed": False,
  },
]
EOL

echo "Syncing ANGLE dependencies with gclient..."
gclient sync --no-history --with_branch_heads --noprehooks

echo "ANGLE setup complete!"
cd ..
