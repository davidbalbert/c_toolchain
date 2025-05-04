#!/bin/bash
set -euo pipefail

# Print usage information
print_usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Build bootstrap GCC (C compiler only) for the specified target architecture."
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

BUILD_DIR="$BUILD_ROOT/build/bootstrap/$TARGET-gcc-$GCC_VERSION"
PREFIX="$BUILD_ROOT/out/bootstrap/$TARGET-gcc-$GCC_VERSION/toolchain"
SYSROOT="$BUILD_ROOT/out/bootstrap/$TARGET-gcc-$GCC_VERSION/sysroot"

GCC_BUILD_DIR="$BUILD_DIR/gcc"

# Clean build directory if requested
if [ "$CLEAN_BUILD" = true ] && [ -d "$GCC_BUILD_DIR" ]; then
    echo "Cleaning $GCC_BUILD_DIR..."
    rm -rf "$GCC_BUILD_DIR"
fi

mkdir -p "$GCC_BUILD_DIR"
mkdir -p "$SYSROOT"

# Set reproducibility environment variables
export LC_ALL=C
export SOURCE_DATE_EPOCH=1

echo "Building bootstrap GCC-$GCC_VERSION"
echo "Host: $HOST"
echo "Target: $TARGET"
echo "Source: $SRC_DIR/gcc-$GCC_VERSION"
echo "Build: $GCC_BUILD_DIR"
echo "Prefix: $PREFIX"
echo "Sysroot: $SYSROOT"
echo

# Check that binutils are installed in PREFIX
if [ ! -x "$PREFIX/bin/$TARGET-as" ]; then
    echo "Error: Binutils not found in $PREFIX"
    echo "Please build binutils first using scripts/build-binutils.sh --bootstrap"
    exit 1
fi

# Add binutils to PATH
export PATH="$PREFIX/bin:$PATH"

# Change to build directory
cd "$GCC_BUILD_DIR"

# Configure GCC
echo "Configuring bootstrap GCC..."
"$SRC_DIR/gcc-$GCC_VERSION/configure" \
    --host="$HOST" \
    --target="$TARGET" \
    --prefix="$PREFIX" \
    --with-glibc-version="$GLIBC_VERSION" \
    --with-gmp="$PREFIX" \
    --with-sysroot="$SYSROOT" \
    --with-newlib \
    --without-headers \
    --enable-default-pie \
    --enable-default-ssp \
    --enable-static \
    --disable-nls \
    --disable-shared \
    --disable-multilib \
    --disable-threads \
    --disable-libatomic \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libvtv \
    --disable-libstdcxx \
    --disable-bootstrap \
    --enable-languages=c,c++ \
    CFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=." \
    CXXFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=."

# Build GCC
echo "Building bootstrap GCC..."
make -j$(nproc)

echo "Installing bootstrap GCC..."
make install

echo "Bootstrap GCC build complete. Installed to $PREFIX"
