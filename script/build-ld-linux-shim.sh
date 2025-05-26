#!/bin/bash
set -euo pipefail

print_usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Build ld-linux-shim for the specified target architecture."
    echo ""
    echo "Options:"
    echo "  --build-root=DIR     Set the build root directory (default: project root)"
    echo "  --host=TRIPLE        Set the host architecture triple (default: system compiler)"
    echo "  --target=TRIPLE      Set the target architecture triple (default: host triple)"
    echo "  --clean              Clean the build directory before building"
    echo "  --help               Display this help message"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/common.sh"

# Default values
BUILD_ROOT="$ROOT_DIR"
SYSTEM_TRIPLE=$(gcc -dumpmachine)
HOST="$SYSTEM_TRIPLE"
TARGET=""
CLEAN_BUILD=false

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

if [ -z "$TARGET" ]; then
    TARGET="$HOST"
fi

ARCH="${TARGET%%-*}"

SRC_DIR="$ROOT_DIR/ld-linux-shim"
BUILD_DIR="$BUILD_ROOT/build/$HOST/$TARGET-gcc-$GCC_VERSION/ld-linux-shim"
PREFIX="$BUILD_ROOT/out/$HOST/$TARGET-gcc-$GCC_VERSION/toolchain"

if [ "$CLEAN_BUILD" = true ] && [ -d "$BUILD_DIR" ]; then
    echo "Cleaning $BUILD_DIR..."
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR/build"
ln -sf "$SRC_DIR" "$BUILD_DIR/src"

mkdir -p "$PREFIX/libexec"

# Set reproducibility environment variables
export LC_ALL=C
export SOURCE_DATE_EPOCH=1

echo "Building ld-linux-shim"
echo "Host:    $HOST"
echo "Target:  $TARGET"
echo "Arch:    $ARCH"
echo "Source:  $SRC_DIR"
echo "Build:   $BUILD_DIR"
echo "Prefix:  $PREFIX"
echo

# Build using Makefile
echo "Building ld-linux-shim for $ARCH..."
cd "$BUILD_DIR"
make -f "$BUILD_DIR/src/Makefile" \
    ARCH="$ARCH"

# Copy to output directory
make -f "$BUILD_DIR/src/Makefile" \
    install \
    DESTDIR="$PREFIX/libexec"

echo "ld-linux-shim installed successfully at $PREFIX/libexec/ld-linux-shim"
