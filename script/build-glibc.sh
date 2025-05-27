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
    echo "  --host=TRIPLE        Set the host architecture triple (default: system triple)"
    echo "  --target=TRIPLE      Set the target architecture triple (default: same as host)"
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
CROSS=false

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

if [ "$HOST" = "$TARGET" ] && [ "$HOST" = "$SYSTEM_TRIPLE" ]; then
    CROSS=false
else
    CROSS=true
fi

SRC_DIR="$BUILD_ROOT/src"
PKG_DIR="$BUILD_ROOT/pkg"

BOOTSTRAP_PREFIX="$BUILD_ROOT/out/bootstrap/$TARGET-gcc-$GCC_VERSION/toolchain/usr"
NATIVE_PREFIX="$BUILD_ROOT/out/$HOST/$HOST-gcc-$GCC_VERSION/toolchain/usr"
SYSROOT="$BUILD_ROOT/out/$HOST/$TARGET-gcc-$GCC_VERSION/sysroot"

BUILD_DIR="$BUILD_ROOT/build/$HOST/$TARGET-gcc-$GCC_VERSION"

GLIBC_BUILD_DIR="$BUILD_DIR/glibc/build"

if [ "$CLEAN_BUILD" = true ] && [ -d "$BUILD_DIR/glibc" ]; then
    echo "Cleaning $BUILD_DIR/glibc..."
    rm -rf "$BUILD_DIR/glibc"
fi

mkdir -p "$GLIBC_BUILD_DIR"

# Create symlink to source directory
ln -sfn "$SRC_DIR/glibc-$GLIBC_VERSION" "$BUILD_DIR/glibc/src"
mkdir -p "$SYSROOT"

# Set reproducibility environment variables
export LC_ALL=C
export SOURCE_DATE_EPOCH=1

if [ "$CROSS" = false ] && [ ! -x "$NATIVE_PREFIX/bin/$TARGET-gcc" ]; then
    PATH="$BOOTSTRAP_PREFIX/bin:$PATH"
fi
export PATH="$NATIVE_PREFIX/bin:$PATH"

echo "Building glibc $GLIBC_VERSION"
echo "Host:    $HOST"
echo "Target:  $TARGET"
echo "Source:  $SRC_DIR/glibc-$GLIBC_VERSION"
echo "Build:   $GLIBC_BUILD_DIR"
echo "Sysroot: $SYSROOT"
echo "Path:    $PATH"
echo

if [ ! -d "$SYSROOT/usr/include/linux" ]; then
    echo "Error: Linux kernel headers must be installed first"
    echo "Run build-linux-headers.sh --host=$HOST --target=$TARGET first"
    exit 1
fi

cd "$GLIBC_BUILD_DIR"

echo "Configuring glibc..."
"../src/configure" \
    --prefix=/usr \
    --host="$TARGET" \
    --enable-kernel=5.4 \
    --with-headers="$SYSROOT/usr/include" \
    libc_cv_slibdir=/usr/lib \
    CFLAGS="-O2 -g -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=." \
    CXXFLAGS="-O2 -g -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=."

echo "Building glibc..."
make -j$(nproc) \

echo "Installing glibc..."
make DESTDIR="$SYSROOT" install

echo "glibc $GLIBC_VERSION built and installed to $SYSROOT"
