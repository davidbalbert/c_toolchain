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
    echo "  --clean              Clean the build directory before building"
    echo "  --help               Display this help message"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source common definitions
source "$SCRIPT_DIR/common.sh"

# Default values
BUILD_ROOT="$ROOT_DIR"
SYSTEM_TRIPLE=$(gcc -dumpmachine)
HOST="$SYSTEM_TRIPLE"
TARGET="$SYSTEM_TRIPLE"
CLEAN_BUILD=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --build-root=*)
            BUILD_ROOT="${arg#*=}"
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

PREFIX="$BUILD_ROOT/out/bootstrap/$TARGET-gcc-$GCC_VERSION/toolchain"
BUILD_DIR="$BUILD_ROOT/build/bootstrap/$TARGET-gcc-$GCC_VERSION"
SYSROOT="$BUILD_ROOT/out/$HOST/$TARGET-gcc-$GCC_VERSION/sysroot"

LIBSTDCXX_BUILD_DIR="$BUILD_DIR/libstdc++/build"

if [ "$CLEAN_BUILD" = true ] && [ -d "$BUILD_DIR/libstdc++" ]; then
    echo "Cleaning $BUILD_DIR/libstdc++..."
    rm -rf "$BUILD_DIR/libstdc++"
fi

mkdir -p "$LIBSTDCXX_BUILD_DIR"

ln -sfn "$SRC_DIR/gcc-$GCC_VERSION/libstdc++-v3" "$BUILD_DIR/libstdc++/src"
mkdir -p "$SYSROOT"

# Set reproducibility environment variables
export LC_ALL=C.UTF-8

TIMESTAMP_FILE="$SRC_DIR/gcc-$GCC_VERSION/.timestamp"
if [ -f "$TIMESTAMP_FILE" ]; then
    source "$TIMESTAMP_FILE"
else
    echo "Warning: No timestamp file found for libstdc++"
    export SOURCE_DATE_EPOCH=1
fi

export PATH="$PREFIX/bin:$PATH"

echo "Building libstdc++ $GCC_VERSION"
echo "Host:    $HOST"
echo "Target:  $TARGET"
echo "Source:  $SRC_DIR/gcc-$GCC_VERSION/libstdc++-v3"
echo "Build:   $LIBSTDCXX_BUILD_DIR"
echo "Sysroot: $SYSROOT"
echo "Path:    $PATH"
echo

cd "$LIBSTDCXX_BUILD_DIR"

echo "Configuring libstdc++..."
"../src/configure" \
    --prefix=/usr \
    --host="$TARGET" \
    --disable-multilib \
    --disable-nls \
    --disable-libstdcxx-pch \
    --with-gxx-include-dir="/usr/include/c++/$GCC_VERSION" \
    CFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=." \
    CXXFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=."

echo "Building libstdc++..."
make -j$(nproc)

echo "Installing libstdc++..."
TMPDIR=$(mktemp -d)

make DESTDIR="$TMPDIR" install

find "$TMPDIR" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} \;

cp -a "$TMPDIR"/* "$SYSROOT"/
rm -rf "$TMPDIR"

echo "libstdc++ $GCC_VERSION built and installed to $SYSROOT"
