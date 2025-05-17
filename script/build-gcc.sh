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
    echo "  --bootstrap          Build bootstrap gcc using the system compiler"
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
BOOTSTRAP=false

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

if [ -z "$TARGET" ]; then
    TARGET="$HOST"
fi

SRC_DIR="$BUILD_ROOT/src"
PKG_DIR="$BUILD_ROOT/pkg"

if [ "$BOOTSTRAP" != "true" ]; then
    echo "Error: Currently only bootstrap builds are supported (--bootstrap)"
    exit 1
fi

if [ "$BOOTSTRAP" = "true" ]; then
    # In bootstrap mode, host and target must be the current system triple
    if [ "$HOST" != "$SYSTEM_TRIPLE" ]; then
        echo "Error: with --bootstrap, --host must be ($SYSTEM_TRIPLE)"
        exit 1
    fi
    if [ "$TARGET" != "$SYSTEM_TRIPLE" ]; then
        echo "Error: with --bootstrap, --target must be ($SYSTEM_TRIPLE)"
        exit 1
    fi

    BUILD_DIR="$BUILD_ROOT/build/bootstrap/$TARGET-gcc-$GCC_VERSION"
    PREFIX="$BUILD_ROOT/out/bootstrap/$TARGET-gcc-$GCC_VERSION/toolchain"
    SYSROOT="$BUILD_ROOT/out/$HOST/$TARGET-gcc-$GCC_VERSION/sysroot"
else
    BUILD_DIR="$BUILD_ROOT/build/$HOST/$TARGET-gcc-$GCC_VERSION"
    PREFIX="$BUILD_ROOT/out/$HOST/$TARGET-gcc-$GCC_VERSION/toolchain"
    SYSROOT="$PREFIX/sysroot"
fi

GCC_BUILD_DIR="$BUILD_DIR/gcc"

if [ "$CLEAN_BUILD" = true ] && [ -d "$GCC_BUILD_DIR" ]; then
    echo "Cleaning $GCC_BUILD_DIR..."
    rm -rf "$GCC_BUILD_DIR"
fi

mkdir -p "$GCC_BUILD_DIR"
cd "$GCC_BUILD_DIR"

mkdir -p "$PREFIX"

if [ "$BOOTSTRAP" != "true" ]; then
    # In non-bootstrap builds, sysroot and toolchain are siblings. When GCC is built
    # with a sysroot inside its prefix, it uses relative paths, which means the toolchain
    # can be moved around.
    #
    # $PREFIX/sysroot is the same as $SYSROOT in non-bootstrap builds. Using the former
    # because its clearer what's going on.
    ln -sf "../sysroot" "$PREFIX/sysroot"
fi

# Set reproducibility environment variables
export LC_ALL=C
export SOURCE_DATE_EPOCH=1

if [ "$BOOTSTRAP" != "true" ] && [ "$HOST" = "$TARGET" ] && [ "$HOST" = "$SYSTEM_TRIPLE" ]; then
    BOOTSTRAP_TOOLCHAIN="$BUILD_ROOT/out/bootstrap/$TARGET-gcc-$GCC_VERSION/toolchain"
    if [ -d "$BOOTSTRAP_TOOLCHAIN/bin" ]; then
        export PATH="$BOOTSTRAP_TOOLCHAIN/bin:$PATH"
    else
        echo "Warning: Bootstrap toolchain not found at $BOOTSTRAP_TOOLCHAIN"
        echo "You may need to build it first with --bootstrap"
    fi
fi

export PATH="$PREFIX/bin:$PATH"

if [ ! -x "$PREFIX/bin/$TARGET-as" ]; then
    echo "Error: Binutils not found in $PREFIX"
    echo "Please build binutils first using scripts/build-binutils.sh --bootstrap"
    exit 1
fi

echo "Building gcc-$GCC_VERSION"
echo "Host:   $HOST"
echo "Target: $TARGET"
echo "Source: $SRC_DIR/gcc-$GCC_VERSION"
echo "Build:  $GCC_BUILD_DIR"
echo "Prefix: $PREFIX"
echo "Path:   $PATH"
echo

echo "Configuring GCC..."

"$SRC_DIR/gcc-$GCC_VERSION/configure" \
    --host="$HOST" \
    --target="$TARGET" \
    --prefix="$PREFIX" \
    --with-glibc-version="$GLIBC_VERSION" \
    --with-sysroot="$SYSROOT" \
    --with-newlib \
    --without-headers \
    --with-gmp="$PREFIX" \
    --enable-default-pie \
    --enable-default-ssp \
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
    --with-gxx-include-dir="$SYSROOT/usr/include/c++/$GCC_VERSION" \
    CFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=." \
    CXXFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=."

echo "Building bootstrap GCC..."
make -j$(nproc)

echo "Installing bootstrap GCC..."
make install

echo "Bootstrap GCC build complete. Installed to $PREFIX"
