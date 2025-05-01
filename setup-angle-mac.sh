#!/bin/bash
set -e

# Use environment variables for commits if specified, otherwise use latest
ANGLE_COMMIT=${ANGLE_COMMIT:-""}
DEPOT_TOOLS_COMMIT=${DEPOT_TOOLS_COMMIT:-""}

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
    git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git

    # Checkout specific commit if provided
    if [ ! -z "$DEPOT_TOOLS_COMMIT" ]; then
        cd depot_tools
        git fetch --depth 1 origin $DEPOT_TOOLS_COMMIT
        git checkout $DEPOT_TOOLS_COMMIT
        cd ..
    fi
else
    echo "depot_tools directory already exists, updating..."
    cd depot_tools

    if [ ! -z "$DEPOT_TOOLS_COMMIT" ]; then
        echo "Checking out specified commit: $DEPOT_TOOLS_COMMIT"
        git fetch --depth 1 origin $DEPOT_TOOLS_COMMIT
        git checkout $DEPOT_TOOLS_COMMIT
    else
        echo "Using latest depot_tools"
        git pull
    fi
    cd ..
fi

# Add depot_tools to PATH
export PATH="$PATH:$SCRIPT_DIR/depot_tools"

# Clone or update ANGLE
if [ ! -d "angle" ]; then
    echo "Cloning ANGLE repository..."
    git clone --depth 1 https://chromium.googlesource.com/angle/angle

    # Checkout specific commit if provided
    if [ ! -z "$ANGLE_COMMIT" ]; then
        cd angle
        git fetch --depth 1 origin $ANGLE_COMMIT
        git checkout $ANGLE_COMMIT
        cd ..
    fi
else
    echo "ANGLE directory already exists, updating..."
    cd angle

    if [ ! -z "$ANGLE_COMMIT" ]; then
        echo "Checking out specified commit: $ANGLE_COMMIT"
        git fetch --depth 1 origin $ANGLE_COMMIT
        git checkout $ANGLE_COMMIT
    else
        echo "Using latest ANGLE"
        git pull
    fi
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

# Store the current ANGLE commit hash for reference
cd angle
CURRENT_ANGLE_COMMIT=$(git rev-parse HEAD)
echo "Current ANGLE commit: $CURRENT_ANGLE_COMMIT"
echo $CURRENT_ANGLE_COMMIT > ../.angle_commit
cd ..