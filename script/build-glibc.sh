#!/bin/bash
set -euo pipefail

# Print usage information
print_usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Build and install glibc for the specified target architecture."
    echo ""
    echo "Options:"
    echo "  --build-root=DIR     Set the build root directory (default: project root)"
    echo "  --target=TRIPLE      Set the target architecture triple"
    echo "  --clean              Clean the build directory before building"
    echo "  --bootstrap          Build bootstrap glibc using the system compiler"
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

    BUILD_DIR="$BUILD_ROOT/build/bootstrap/$TARGET-gcc-$GCC_VERSION"
    SYSROOT="$BUILD_ROOT/out/bootstrap/$TARGET-gcc-$GCC_VERSION/sysroot"
else
    BUILD_DIR="$BUILD_ROOT/build/$HOST/$TARGET-gcc-$GCC_VERSION"
    SYSROOT="$BUILD_ROOT/out/$HOST/$TARGET-gcc-$GCC_VERSION/sysroot"
fi

GLIBC_BUILD_DIR="$BUILD_DIR/glibc-build"

# Get the architecture from the target triple
TARGET_ARCH=$(echo "$TARGET" | cut -d'-' -f1)
case "$TARGET_ARCH" in
    x86_64)
        GLIBC_ARCH="x86_64"
        ;;
    aarch64)
        GLIBC_ARCH="aarch64"
        ;;
    *)
        echo "Error: Unsupported architecture: $TARGET_ARCH"
        exit 1
        ;;
esac

# Clean build directory if requested
if [ "$CLEAN_BUILD" = true ] && [ -d "$GLIBC_BUILD_DIR" ]; then
    echo "Cleaning $GLIBC_BUILD_DIR..."
    rm -rf "$GLIBC_BUILD_DIR"
fi

# Create build directory if it doesn't exist
mkdir -p "$GLIBC_BUILD_DIR"

# Set reproducibility environment variables
export LC_ALL=C
export SOURCE_DATE_EPOCH=1

echo "Building glibc $GLIBC_VERSION"
echo "Target architecture: $TARGET_ARCH (glibc: $GLIBC_ARCH)"
echo "Bootstrap: $BOOTSTRAP"
echo "Source: $SRC_DIR/glibc-$GLIBC_VERSION"
echo "Build: $GLIBC_BUILD_DIR"
echo "Sysroot: $SYSROOT"
echo

# Ensure the kernel headers are installed first
if [ ! -d "$SYSROOT/usr/include/linux" ]; then
    echo "Error: Linux kernel headers must be installed first"
    echo "Run build-linux-headers.sh first"
    exit 1
fi

# Change to build directory
cd "$GLIBC_BUILD_DIR"

# Configure glibc
echo "Configuring glibc..."
"$SRC_DIR/glibc-$GLIBC_VERSION/configure" \
    --prefix=/usr \
    --build="$SYSTEM_TRIPLE" \
    --host="$TARGET" \
    --enable-kernel=5.4 \
    --with-headers="$SYSROOT/usr/include" \
    libc_cv_slibdir=/usr/lib \

# Build glibc
echo "Building glibc..."
make -j$(nproc) \
    BUILD_CFLAGS="-O2 -g  -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=." \
    BUILD_CXXFLAGS="-O2 -g  -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=."

# Install glibc to the sysroot
echo "Installing glibc to sysroot..."
make DESTDIR="$SYSROOT" install

echo "glibc $GLIBC_VERSION built and installed to $SYSROOT"
