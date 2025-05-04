#!/bin/bash
set -euo pipefail

# Print usage information
print_usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Build bootstrap libstdc++ for the specified target architecture."
    echo ""
    echo "Options:"
    echo "  --build-root=DIR     Set the build root directory (default: project root)"
    echo "  --host=TRIPLE        Set the host architecture triple"
    echo "  --target=TRIPLE      Set the target architecture triple"
    echo "  --clean              Clean the build directory before building"
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

# Versions are defined in common.sh

SYSTEM_TRIPLE=$(gcc -dumpmachine)
echo "Detected system: $SYSTEM_TRIPLE"

# We only support bootstrap builds for now
# In bootstrap mode, host and target must be the current system triple
if [ -z "$HOST" ]; then
    HOST="$SYSTEM_TRIPLE"
elif [ "$HOST" != "$SYSTEM_TRIPLE" ]; then
    echo "Error: for bootstrap, --host must be ($SYSTEM_TRIPLE)"
    exit 1
fi

if [ -z "$TARGET" ]; then
    TARGET="$SYSTEM_TRIPLE"
elif [ "$TARGET" != "$SYSTEM_TRIPLE" ]; then
    echo "Error: for bootstrap, --target must be ($SYSTEM_TRIPLE)"
    exit 1
fi

BUILD_DIR="$BUILD_ROOT/build/bootstrap/toolchains/$TARGET-gcc-$GCC_VERSION"
PREFIX="$BUILD_ROOT/out/bootstrap/toolchains/$TARGET-gcc-$GCC_VERSION"
SYSROOT="$BUILD_ROOT/out/bootstrap/sysroots/$TARGET-glibc-$GLIBC_VERSION"

LIBSTDCXX_BUILD_DIR="$BUILD_DIR/libstdcxx"

# Clean build directory if requested
if [ "$CLEAN_BUILD" = true ] && [ -d "$LIBSTDCXX_BUILD_DIR" ]; then
    echo "Cleaning $LIBSTDCXX_BUILD_DIR..."
    rm -rf "$LIBSTDCXX_BUILD_DIR"
fi

mkdir -p "$LIBSTDCXX_BUILD_DIR"
mkdir -p "$SYSROOT"

# Set reproducibility environment variables
export LC_ALL=C
export SOURCE_DATE_EPOCH=1

echo "Building bootstrap libstdc++"
echo "Host: $HOST"
echo "Target: $TARGET"
echo "Source: $SRC_DIR/gcc-$GCC_VERSION/libstdc++-v3"
echo "Build: $LIBSTDCXX_BUILD_DIR"
echo "Prefix: $PREFIX"
echo "Sysroot: $SYSROOT"
echo

# Check that bootstrap GCC is installed in PREFIX
if [ ! -x "$PREFIX/bin/$TARGET-gcc" ]; then
    echo "Error: Bootstrap GCC not found in $PREFIX"
    echo "Please build bootstrap GCC first using scripts/build-bootstrap-gcc.sh"
    exit 1
fi

# Add the bootstrap toolchain to PATH
export PATH="$PREFIX/bin:$PATH"

# Change to build directory
cd "$LIBSTDCXX_BUILD_DIR"

# Configure libstdc++-v3
echo "Configuring bootstrap libstdc++..."
"$SRC_DIR/gcc-$GCC_VERSION/libstdc++-v3/configure" \
    --build="$SYSTEM_TRIPLE" \
    --host="$HOST" \
    --target="$TARGET" \
    --prefix=/usr \
    --disable-multilib \
    --disable-nls \
    --disable-libstdcxx-pch \
    --disable-shared \
    --enable-static \
    CFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=." \
    CXXFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=."

# Build libstdc++
echo "Building bootstrap libstdc++..."
make -j$(nproc)

echo "Installing bootstrap libstdc++..."
make DESTDIR="$SYSROOT" install

echo "Bootstrap libstdc++ build complete. Installed to $PREFIX"
