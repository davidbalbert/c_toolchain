#!/bin/bash
set -euo pipefail

# Print usage information
print_usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Install Linux kernel headers for the specified target architecture."
    echo ""
    echo "Options:"
    echo "  --build-root=DIR     Set the build root directory (default: project root)"
    echo "  --host=TRIPLE        Set the host architecture triple (default: $(gcc -dumpmachine))"
    echo "  --target=TRIPLE      Set the target architecture triple (default: $(gcc -dumpmachine))"
    echo "  --clean              Clean the build directory before building"
    echo "  --help               Display this help message"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Default values
BUILD_ROOT="$(dirname "$SCRIPT_DIR")"
SYSTEM_TRIPLE=$(gcc -dumpmachine)
HOST="$SYSTEM_TRIPLE"
TARGET=""
CLEAN_BUILD=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --build-root=*)
            BUILD_ROOT="${arg#*=}"
            ;;
        --target=*)
            TARGET="${arg#*=}"
            ;;
        --clean)
            CLEAN_BUILD=true
            ;;
        --host=*)
            HOST="${arg#*=}"
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

SRC_DIR="$BUILD_ROOT/src"
PKG_DIR="$BUILD_ROOT/pkg"

BUILD_DIR="$BUILD_ROOT/build/$HOST/$TARGET-gcc-$GCC_VERSION"
SYSROOT="$BUILD_ROOT/out/$HOST/$TARGET-gcc-$GCC_VERSION/sysroot"

LINUX_BUILD_DIR="$BUILD_DIR/linux-headers/build"

# Get the architecture from the target triple
TARGET_ARCH=$(echo "$TARGET" | cut -d'-' -f1)
case "$TARGET_ARCH" in
    x86_64)
        KERNEL_ARCH="x86_64"
        ;;
    aarch64)
        KERNEL_ARCH="arm64"
        ;;
    *)
        echo "Error: Unsupported architecture: $TARGET_ARCH"
        exit 1
        ;;
esac

if [ "$CLEAN_BUILD" = true ] && [ -d "$BUILD_DIR/linux-headers" ]; then
    echo "Cleaning $BUILD_DIR/linux-headers..."
    rm -rf "$BUILD_DIR/linux-headers"
fi

mkdir -p "$LINUX_BUILD_DIR"

# Create symlink to source directory
ln -sf "$SRC_DIR/linux-$LINUX_VERSION" "$BUILD_DIR/linux-headers/src"
mkdir -p "$SYSROOT"

# Set reproducibility environment variables
export LC_ALL=C
export SOURCE_DATE_EPOCH=1

echo "Installing Linux kernel headers $LINUX_VERSION"
echo "Target architecture: $TARGET_ARCH (kernel: $KERNEL_ARCH)"
echo "Source:  $SRC_DIR/linux-$LINUX_VERSION"
echo "Build:   $LINUX_BUILD_DIR"
echo "Sysroot: $SYSROOT"
echo

cd "$BUILD_DIR/linux-headers/src"
# Clean the kernel source directory
make mrproper

echo "Installing kernel headers..."
make ARCH="$KERNEL_ARCH" \
     INSTALL_HDR_PATH="$SYSROOT/usr" \
     O="$LINUX_BUILD_DIR" \
     headers_install

echo "Linux kernel headers installed in $SYSROOT/usr/include"
