#!/bin/bash
set -euo pipefail

# Print usage information
print_usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Build GMP (GNU Multiple Precision Arithmetic Library) for the specified target architecture."
    echo ""
    echo "Options:"
    echo "  --build-root=DIR     Set the build root directory (default: project root)"
    echo "  --host=TRIPLE        Set the host architecture triple"
    echo "  --target=TRIPLE      Set the target architecture triple"
    echo "  --clean              Clean the build directory before building"
    echo "  --bootstrap          Build bootstrap GMP using the system compiler"
    echo "  --help               Display this help message"
}

# Base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source common definitions
source "$SCRIPT_DIR/common.sh"

# Default values
BUILD_ROOT="$ROOT_DIR"
HOST=""
TARGET=""
CLEAN_BUILD=false
BOOTSTRAP=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --build-root=*)
            BUILD_ROOT="${arg#*=}"
            ;;
        --host=*)
            HOST="${arg#*=}"
            ;;
        --target=*)
            TARGET="${arg#*=}"
            ;;
        --clean)
            CLEAN_BUILD=true
            ;;
        --bootstrap)
            BOOTSTRAP=true
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$arg'"
            print_usage
            exit 1
            ;;
    esac
done

SRC_DIR="$BUILD_ROOT/src"
PKG_DIR="$BUILD_ROOT/pkg"

if [ "$BOOTSTRAP" != "true" ]; then
    echo "Error: Currently only bootstrap builds are supported (--bootstrap)"
    exit 1
fi

# Versions are defined in common.sh

SYSTEM_TRIPLE=$(gcc -dumpmachine)
echo "Detected system: $SYSTEM_TRIPLE"

# Set paths according to our directory structure
if [ "$BOOTSTRAP" = "true" ]; then
    # In bootstrap mode, host and target must be the current system triple
    if [ -z "$HOST" ]; then
        HOST="$SYSTEM_TRIPLE"
    elif [ "$HOST" != "$SYSTEM_TRIPLE" ]; then
        echo "Error: with --bootstrap, --host must be ($SYSTEM_TRIPLE)"
        exit 1
    fi

    if [ -z "$TARGET" ]; then
        TARGET="$SYSTEM_TRIPLE"
    elif [ "$TARGET" != "$SYSTEM_TRIPLE" ]; then
        echo "Error: with --bootstrap, --target must be ($SYSTEM_TRIPLE)"
        exit 1
    fi

    BUILD_DIR="$BUILD_ROOT/build/bootstrap/$TARGET-gcc-$GCC_VERSION"
    PREFIX="$BUILD_ROOT/out/bootstrap/$TARGET-gcc-$GCC_VERSION/toolchain"
else
    BUILD_DIR="$BUILD_ROOT/build/$HOST/$TARGET-gcc-$GCC_VERSION"
    PREFIX="$BUILD_ROOT/out/$HOST/$TARGET-gcc-$GCC_VERSION/toolchain"
fi

GMP_BUILD_DIR="$BUILD_DIR/gmp"

# Clean build directory if requested
if [ "$CLEAN_BUILD" = true ] && [ -d "$GMP_BUILD_DIR" ]; then
    echo "Cleaning $GMP_BUILD_DIR..."
    rm -rf "$GMP_BUILD_DIR"
fi

# Create build directory
mkdir -p "$GMP_BUILD_DIR"

# Set reproducibility environment variables
export LC_ALL=C
export SOURCE_DATE_EPOCH=1

echo "Building gmp-$GMP_VERSION"
echo "Host: $HOST"
echo "Target: $TARGET"
echo "Bootstrap: $BOOTSTRAP"
echo "Source: $SRC_DIR/gmp-$GMP_VERSION"
echo "Build: $GMP_BUILD_DIR"
echo "Prefix: $PREFIX"
echo

# Change to build directory
cd "$GMP_BUILD_DIR"

# Configure GMP
echo "Configuring GMP..."
"$SRC_DIR/gmp-$GMP_VERSION/configure" \
    --build="$HOST" \
    --host="$HOST" \
    --prefix="$PREFIX" \
    --disable-shared \
    --enable-static \
    "CONFIG_SHELL=/bin/bash" \
    CFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=." \
    CXXFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=."

# Build and install GMP
echo "Building GMP..."
make -j$(nproc)

echo "Installing GMP..."
make install

echo "GMP bootstrap build complete. Installed to $PREFIX"
