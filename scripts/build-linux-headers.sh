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
    echo "  --target=TRIPLE      Set the target architecture triple"
    echo "  --clean              Clean the build directory before building"
    echo "  --bootstrap          Build bootstrap kernel headers using the system compiler"
    echo "  --help               Display this help message"
}

# Base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source common definitions
source "$SCRIPT_DIR/common.sh"

# Default values
BUILD_ROOT="$ROOT_DIR"
TARGET=""
CLEAN_BUILD=false
BOOTSTRAP=false

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
    # In bootstrap mode, target must be the current system triple
    if [ -z "$TARGET" ]; then
        TARGET="$SYSTEM_TRIPLE"
    elif [ "$TARGET" != "$SYSTEM_TRIPLE" ]; then
        echo "Error: with --bootstrap, --target must be ($SYSTEM_TRIPLE)"
        exit 1
    fi

    BUILD_DIR="$BUILD_ROOT/build/bootstrap/sysroots/$TARGET-glibc-$GLIBC_VERSION"
    SYSROOT="$BUILD_ROOT/out/bootstrap/sysroots/$TARGET-glibc-$GLIBC_VERSION"
else
    BUILD_DIR="$BUILD_ROOT/build/sysroots/$TARGET-glibc-$GLIBC_VERSION"
    SYSROOT="$BUILD_ROOT/out/sysroots/$TARGET-glibc-$GLIBC_VERSION"
fi

LINUX_BUILD_DIR="$BUILD_DIR/linux-headers"

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

# Clean build directory if requested
if [ "$CLEAN_BUILD" = true ] && [ -d "$LINUX_BUILD_DIR" ]; then
    echo "Cleaning $LINUX_BUILD_DIR..."
    rm -rf "$LINUX_BUILD_DIR"
fi

# Set reproducibility environment variables
export LC_ALL=C
export SOURCE_DATE_EPOCH=1

echo "Installing Linux kernel headers $LINUX_VERSION"
echo "Target architecture: $TARGET_ARCH (kernel: $KERNEL_ARCH)"
echo "Bootstrap: $BOOTSTRAP"
echo "Source: $SRC_DIR/linux-$LINUX_VERSION"
echo "Sysroot: $SYSROOT"
echo

# Change to Linux source directory
cd "$SRC_DIR/linux-$LINUX_VERSION"

# Clean the kernel source directory
make mrproper

# Install the headers to the sysroot
echo "Installing kernel headers..."
make ARCH="$KERNEL_ARCH" \
     INSTALL_HDR_PATH="$SYSROOT/usr" \
     O="$LINUX_BUILD_DIR" \
     headers_install

echo "Linux kernel headers installed in $SYSROOT/usr/include"
