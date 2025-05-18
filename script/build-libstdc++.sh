#!/bin/bash
set -euo pipefail

# Print usage information
print_usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Build libstdc++ for the specified target architecture."
    echo ""
    echo "Options:"
    echo "  --build-root=DIR     Set the build root directory (default: project root)"
    echo "  --host=TRIPLE        Set the host architecture triple"
    echo "  --target=TRIPLE      Set the target architecture triple"
    echo "  --clean              Clean the build directory before building"
    echo "  --bootstrap          Build libstdc++ using the bootstrap compiler"
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
TARGET=""
CLEAN_BUILD=false
BOOTSTRAP=false
CROSS=false


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

if [ "$BOOTSTRAP" = "true" ] && [ "$HOST" != "$SYSTEM_TRIPLE" ]; then
    echo "Error: with --bootstrap, --host must be $SYSTEM_TRIPLE"
    exit 1
fi

if [ "$BOOTSTRAP" = "true" ] && [ "$TARGET" != "$SYSTEM_TRIPLE" ]; then
    echo "Error: with --bootstrap, --target must be $SYSTEM_TRIPLE"
    exit 1
fi

if [ "$HOST" = "$TARGET" ] && [ "$HOST" = "$SYSTEM_TRIPLE" ]; then
    CROSS=false
else
    CROSS=true
fi

SRC_DIR="$BUILD_ROOT/src"
PKG_DIR="$BUILD_ROOT/pkg"

BOOTSTRAP_PREFIX="$BUILD_ROOT/out/bootstrap/$TARGET-gcc-$GCC_VERSION/toolchain"
NATIVE_PREFIX="$BUILD_ROOT/out/$HOST/$HOST-gcc-$GCC_VERSION/toolchain"

if [ "$BOOTSTRAP" = true ]; then
    BUILD_DIR="$BUILD_ROOT/build/bootstrap/$TARGET-gcc-$GCC_VERSION"
else
    BUILD_DIR="$BUILD_ROOT/build/$HOST/$TARGET-gcc-$GCC_VERSION"
fi

SYSROOT="$BUILD_ROOT/out/$HOST/$TARGET-gcc-$GCC_VERSION/sysroot"

LIBSTDCXX_BUILD_DIR="$BUILD_DIR/libstdcxx"

if [ "$CLEAN_BUILD" = true ] && [ -d "$LIBSTDCXX_BUILD_DIR" ]; then
    echo "Cleaning $LIBSTDCXX_BUILD_DIR..."
    rm -rf "$LIBSTDCXX_BUILD_DIR"
fi

mkdir -p "$LIBSTDCXX_BUILD_DIR"
mkdir -p "$SYSROOT"

# Set reproducibility environment variables
export LC_ALL=C
export SOURCE_DATE_EPOCH=1

if [ "$CROSS" = false ]; then
    PATH="$BOOTSTRAP_PREFIX/bin:$PATH"
fi
export PATH="$NATIVE_PREFIX/bin:$PATH"

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
"$SRC_DIR/gcc-$GCC_VERSION/libstdc++-v3/configure" \
    --build="$SYSTEM_TRIPLE" \
    --host="$HOST" \
    --target="$TARGET" \
    --prefix=/usr \
    --disable-multilib \
    --disable-nls \
    --disable-libstdcxx-pch \
    --with-gxx-include-dir="/usr/include/c++/$GCC_VERSION" \
    CFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=." \
    CXXFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=."

echo "Building libstdc++..."
make -j$(nproc)

echo "Installing libstdc++..."
make DESTDIR="$SYSROOT" install

echo "libstdc++ $GCC_VERSION built and installed to $SYSROOT"
