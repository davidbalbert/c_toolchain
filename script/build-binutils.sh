#!/bin/bash
set -euo pipefail

print_usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Build binutils for the specified target architecture."
    echo ""
    echo "Options:"
    echo "  --build-root=DIR     Set the build root directory (default: project root)"
    echo "  --host=TRIPLE        Set the host architecture triple"
    echo "  --target=TRIPLE      Set the target architecture triple"
    echo "  --clean              Clean the build directory before building"
    echo "  --bootstrap          Build bootstrap binutils using the system compiler"
    echo "  --help               Display this help message"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Default values
BUILD_ROOT="$(dirname "$SCRIPT_DIR")"
SYSTEM_TRIPLE=$(gcc -dumpmachine)
HOST="$SYSTEM_TRIPLE"
TARGET=""
# TOOLCHAIN_PATH variable removed
CLEAN_BUILD=false
BOOTSTRAP=false

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
        # --toolchain-path removed
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

SYSTEM_TRIPLE=$(gcc -dumpmachine)

if [ "$BOOTSTRAP" = "true" ]; then
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

BINUTILS_BUILD_DIR="$BUILD_DIR/binutils"

if [ "$CLEAN_BUILD" = true ] && [ -d "$BINUTILS_BUILD_DIR" ]; then
    echo "Cleaning $BINUTILS_BUILD_DIR..."
    rm -rf "$BINUTILS_BUILD_DIR"
fi

mkdir -p "$BINUTILS_BUILD_DIR"

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

echo "Building binutils-$BINUTILS_VERSION"
echo "Host:    $HOST"
echo "Target:  $TARGET"
echo "Source:  $SRC_DIR/binutils-$BINUTILS_VERSION"
echo "Build:   $BINUTILS_BUILD_DIR"
echo "Prefix:  $PREFIX"
echo "Sysroot: $SYSROOT"
echo "Path:    $PATH"
echo

cd "$BINUTILS_BUILD_DIR"

mkdir -p "$PREFIX"

if [ "$BOOTSTRAP" != "true" ]; then
    # In non-bootstrap builds, sysroot and toolchain are siblings. When GCC is built
    # with a sysroot inside its prefix, it uses relative paths, which means the toolchain
    # can be moved around. Not sure if binutils does the same thing, but it can't hurt
    # to try.
    #
    # $PREFIX/sysroot is the same as $SYSROOT in non-bootstrap builds. Using the former
    # because its clearer what's going on.
    ln -sf "../sysroot" "$PREFIX/sysroot"
fi

CONFIGURE_OPTIONS=(
    "--host=$HOST"
    "--target=$TARGET"
    "--with-sysroot=$SYSROOT"
    "--program-prefix=$TARGET-"
    "--disable-shared"
    "--enable-new-dtags"
    "--disable-werror"
    "--with-stage1-ldflags=-static"
)

if [ "$BOOTSTRAP" == "true" ]; then
    CONFIGURE_OPTIONS+=("--prefix=$PREFIX")
else
    CONFIGURE_OPTIONS+=("--prefix=/")
fi

"$SRC_DIR/binutils-$BINUTILS_VERSION/configure" \
    "${CONFIGURE_OPTIONS[@]}" \
    CFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=." \
    CXXFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=."

exit

echo "Building binutils..."
make -j$(nproc)

echo "Installing binutils..."
if [ "$BOOTSTRAP" == "true" ]; then
    make install
else
    make DESTDIR="$PREFIX" install
fi

echo "Binutils installed to $PREFIX"
