#!/bin/bash
set -euo pipefail

# Base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
BUILD_ROOT="$ROOT_DIR"
TARGET=""
HOST=""
PREFIX=""
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
        --host=*)
            HOST="${arg#*=}"
            ;;
        --prefix=*)
            PREFIX="${arg#*=}"
            ;;
        --clean)
            CLEAN_BUILD=true
            ;;
        --bootstrap)
            BOOTSTRAP=true
            ;;
    esac
done

SRC_DIR="$BUILD_ROOT/src"
PKG_DIR="$BUILD_ROOT/pkg"

if [ "$BOOTSTRAP" != "true" ]; then
    echo "Error: Currently only bootstrap builds are supported (--bootstrap)"
    exit 1
fi

# Get versions from download.sh
BINUTILS_VERSION=$(grep BINUTILS_VERSION "$SCRIPT_DIR/download.sh" | cut -d'"' -f2)
GCC_VERSION=$(grep GCC_VERSION "$SCRIPT_DIR/download.sh" | cut -d'"' -f2)
GLIBC_VERSION=$(grep GLIBC_VERSION "$SCRIPT_DIR/download.sh" | cut -d'"' -f2)

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

    BUILD_DIR="$BUILD_ROOT/build/bootstrap/toolchains/$TARGET-gcc-$GCC_VERSION"
    BINUTILS_BUILD_DIR="$BUILD_DIR/binutils"

    # Set default prefix if not specified
    if [ -z "$PREFIX" ]; then
        PREFIX="$BUILD_ROOT/out/bootstrap/toolchains/$TARGET-gcc-$GCC_VERSION"
    fi

    SYSROOT="$BUILD_ROOT/out/bootstrap/sysroots/$TARGET-glibc-$GLIBC_VERSION"
else
    # This path is not currently used since we require bootstrap
    BUILD_DIR="$BUILD_ROOT/build/toolchains/$HOST/$TARGET-gcc-$GCC_VERSION"
    BINUTILS_BUILD_DIR="$BUILD_DIR/binutils"

    # Set default prefix if not specified
    if [ -z "$PREFIX" ]; then
        PREFIX="$BUILD_ROOT/out/toolchains/$HOST/$TARGET-gcc-$GCC_VERSION"
    fi

    SYSROOT="$BUILD_ROOT/out/sysroots/$TARGET-glibc-$GLIBC_VERSION"
fi

# Clean build directory if requested
if [ "$CLEAN_BUILD" = true ] && [ -d "$BINUTILS_BUILD_DIR" ]; then
    echo "Cleaning $BINUTILS_BUILD_DIR..."
    rm -rf "$BINUTILS_BUILD_DIR"
fi

# Create build directory
mkdir -p "$BINUTILS_BUILD_DIR"

# Create output directories
mkdir -p "$PREFIX/bin" "$PREFIX/lib"
mkdir -p "$SYSROOT"

# Set reproducibility environment variables
export LC_ALL=C
export SOURCE_DATE_EPOCH=1

echo "Building binutils-$BINUTILS_VERSION"
echo "Host: $HOST"
echo "Target: $TARGET"
echo "Bootstrap: $BOOTSTRAP"
echo "Source: $SRC_DIR/binutils-$BINUTILS_VERSION"
echo "Build: $BINUTILS_BUILD_DIR"
echo "Prefix: $PREFIX"
echo "Sysroot: $SYSROOT"
echo

# Change to build directory
cd "$BINUTILS_BUILD_DIR"

# Configure binutils
echo "Configuring binutils..."
"$SRC_DIR/binutils-$BINUTILS_VERSION/configure" \
    --build="$HOST" \
    --host="$HOST" \
    --target="$TARGET" \
    --prefix="$PREFIX" \
    --disable-nls \
    --disable-werror \
    --with-sysroot="$SYSROOT" \
    --disable-shared \
    --enable-static \
    --disable-multilib \
    "CONFIG_SHELL=/bin/bash" \
    CFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=/src -ffile-prefix-map=$BUILD_DIR=/build" \
    CXXFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=/src -ffile-prefix-map=$BUILD_DIR=/build"

# Build and install binutils
echo "Building binutils..."
make -j$(nproc)

echo "Installing binutils..."
make install

echo "Binutils bootstrap build complete. Installed to $PREFIX"
