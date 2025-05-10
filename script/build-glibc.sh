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
    echo "  --bootstrap          Build glibc using the bootstrap compiler"
    echo "  --help               Display this help message"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# Default values
BUILD_ROOT="$(dirname "$SCRIPT_DIR")"
SYSTEM_TRIPLE=$(gcc -dumpmachine)
HOST="$SYSTEM_TRIPLE"
TARGET=""
BOOTSTRAP=false
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
        --bootstrap)
            BOOTSTRAP=true
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

if [ "$BOOTSTRAP" = true ]; then
    PREFIX="$BUILD_ROOT/out/bootstrap/$TARGET-gcc-$GCC_VERSION/toolchain"
else
    PREFIX="$BUILD_ROOT/out/$HOST/$TARGET-gcc-$GCC_VERSION/toolchain"
fi


SRC_DIR="$BUILD_ROOT/src"
PKG_DIR="$BUILD_ROOT/pkg"

BUILD_DIR="$BUILD_ROOT/build/$HOST/$TARGET-gcc-$GCC_VERSION"
SYSROOT="$BUILD_ROOT/out/$HOST/$TARGET-gcc-$GCC_VERSION/sysroot"

GLIBC_BUILD_DIR="$BUILD_DIR/glibc-build"

if [ "$CLEAN_BUILD" = true ] && [ -d "$GLIBC_BUILD_DIR" ]; then
    echo "Cleaning $GLIBC_BUILD_DIR..."
    rm -rf "$GLIBC_BUILD_DIR"
fi

mkdir -p "$GLIBC_BUILD_DIR"
mkdir -p "$SYSROOT"

# Set reproducibility environment variables
export LC_ALL=C
export SOURCE_DATE_EPOCH=1

if [ "$BOOTSTRAP" != "true" ] && [ "$HOST" = "$TARGET" ] && [ "$HOST" = "$SYSTEM_TRIPLE" ]; then
    BOOTSTRAP_TOOLCHAIN="$BUILD_ROOT/out/bootstrap/$TARGET-gcc-$GCC_VERSION/toolchain"
    if [ -d "$BOOTSTRAP_TOOLCHAIN/bin" ]; then
        export PATH="$BOOTSTRAP_TOOLCHAIN/bin:$PATH"
        echo "Using bootstrap toolchain: $BOOTSTRAP_TOOLCHAIN"
    else
        echo "Warning: Bootstrap toolchain not found at $BOOTSTRAP_TOOLCHAIN"
        echo "You may need to build it first with --bootstrap"
    fi
fi

export PATH="$PREFIX/bin:$PATH"

echo "Building glibc $GLIBC_VERSION"
echo "Host:    $HOST"
echo "Target:  $TARGET"
echo "Source:  $SRC_DIR/glibc-$GLIBC_VERSION"
echo "Build:   $GLIBC_BUILD_DIR"
echo "Prefix:  $PREFIX"
echo "Sysroot: $SYSROOT"
echo "Path:    $PATH"
echo

# Ensure the kernel headers are installed first
if [ ! -d "$SYSROOT/usr/include/linux" ]; then
    echo "Error: Linux kernel headers must be installed first"
    echo "Run build-linux-headers.sh --host=$HOST --target=$TARGET first"
    exit 1
fi

cd "$GLIBC_BUILD_DIR"

echo "Configuring glibc..."
"$SRC_DIR/glibc-$GLIBC_VERSION/configure" \
    --prefix=/usr \
    --host="$TARGET" \
    --enable-kernel=5.4 \
    --with-headers="$SYSROOT/usr/include" \
    libc_cv_slibdir=/usr/lib \

echo "Building glibc..."
make -j$(nproc) \
    BUILD_CFLAGS="-O2 -g -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=." \
    BUILD_CXXFLAGS="-O2 -g -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=."

echo "Installing glibc to sysroot..."
make DESTDIR="$SYSROOT" install

echo "glibc $GLIBC_VERSION built and installed to $SYSROOT"
