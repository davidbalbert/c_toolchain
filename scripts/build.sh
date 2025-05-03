#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

TARGET=""
HOST=""
BUILD_ROOT="$ROOT_DIR"

function print_usage {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --host=<host>          Host architecture (required)"
    echo "  --target=<target>      Target architecture (e.g., aarch64-unknown-linux-gnu)"
    echo "  --build-root=<path>    Root directory for build, src, and out dirs (default: workspace root)"
    echo "  --help                 Print this help message"
}

# Parse arguments
for arg in "$@"; do
    case $arg in
        --host=*)
            HOST="${arg#*=}"
            ;;
        --target=*)
            TARGET="${arg#*=}"
            ;;
        --build-root=*)
            BUILD_ROOT="${arg#*=}"
            # Update derived directories
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            print_usage
            exit 1
            ;;
    esac
done

SRC_DIR="$BUILD_ROOT/src"
BUILD_DIR="$BUILD_ROOT/build"
OUT_DIR="$BUILD_ROOT/out"
PKG_DIR="$BUILD_ROOT/pkg"

# Check for required arguments
if [ -z "$TARGET" ]; then
    echo "Error: Target architecture not specified"
    print_usage
    exit 1
fi

if [ -z "$HOST" ]; then
    echo "Error: Host architecture not specified"
    print_usage
    exit 1
fi

# Show build root information
echo "Using build root: $BUILD_ROOT"
if [[ "$BUILD_ROOT" == "/tmp"* ]]; then
    echo "Note: Using temporary directory. Files will be lost after system reboot."
fi

# Create directories
mkdir -p "$SRC_DIR" "$BUILD_DIR" "$OUT_DIR" "$PKG_DIR"

# Export paths and architecture settings for component scripts
export BUILD_ROOT_SRC_DIR="$SRC_DIR"
export BUILD_ROOT_BUILD_DIR="$BUILD_DIR"
export BUILD_ROOT_OUT_DIR="$OUT_DIR"
export BUILD_ROOT_PKG_DIR="$PKG_DIR"
export BUILD_HOST="$HOST"

# Download sources if needed
if [ ! -d "$SRC_DIR/binutils-"* ] || [ ! -d "$SRC_DIR/gcc-"* ]; then
    echo "Downloading and extracting source packages..."
    "$SCRIPT_DIR/download.sh" --src-dir="$SRC_DIR" --pkg-dir="$PKG_DIR"
fi

# Output prefix
PREFIX="$OUT_DIR/$TARGET"

# Build the toolchain components
echo "Building toolchain for target: $TARGET"
echo "Host architecture: $HOST"
echo "Source: $SRC_DIR"
echo "Build: $BUILD_DIR"
echo "Output: $OUT_DIR"

# Component builds will be added here

echo "Build complete. Toolchain is available at: $PREFIX"
