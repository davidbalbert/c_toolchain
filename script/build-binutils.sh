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
CLEAN_BUILD=false
BOOTSTRAP=false
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
TARGET_PREFIX="$BUILD_ROOT/out/$HOST/$TARGET-gcc-$GCC_VERSION/toolchain"

SYSROOT="$BUILD_ROOT/out/$HOST/$TARGET-gcc-$GCC_VERSION/sysroot"

if [ "$BOOTSTRAP" = "true" ]; then
    BUILD_DIR="$BUILD_ROOT/build/bootstrap/$TARGET-gcc-$GCC_VERSION"
    PREFIX="$BOOTSTRAP_PREFIX"
else
    BUILD_DIR="$BUILD_ROOT/build/$HOST/$TARGET-gcc-$GCC_VERSION"
    PREFIX="$TARGET_PREFIX"
fi

BINUTILS_BUILD_DIR="$BUILD_DIR/binutils/build"

if [ "$CLEAN_BUILD" = true ] && [ -d "$BUILD_DIR/binutils" ]; then
    echo "Cleaning $BUILD_DIR/binutils..."
    rm -rf "$BUILD_DIR/binutils"
fi

mkdir -p "$BINUTILS_BUILD_DIR"

ln -sfn "$SRC_DIR/binutils-$BINUTILS_VERSION" "$BUILD_DIR/binutils/src"
mkdir -p "$PREFIX"

# Set reproducibility environment variables
export LC_ALL=C.UTF-8

TIMESTAMP_FILE="$SRC_DIR/binutils-$BINUTILS_VERSION/.timestamp"
if [ -f "$TIMESTAMP_FILE" ]; then
    source "$TIMESTAMP_FILE"
else
    echo "Warning: No timestamp file found for binutils"
    export SOURCE_DATE_EPOCH=1
fi

if [ "$CROSS" = false ]; then
    PATH="$BOOTSTRAP_PREFIX/bin:$PATH"
fi
export PATH="$NATIVE_PREFIX/bin:$PATH"

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

CONFIGURE_OPTIONS=(
    "--host=$HOST"
    "--target=$TARGET"
    "--prefix="
    "--with-sysroot=/sysroot"
    "--program-prefix=$TARGET-"
    "--disable-shared"
    "--enable-new-dtags"
    "--disable-werror"
)

if [ "$CROSS" = true ] || [ "$BOOTSTRAP" = true ]; then
    "../src/configure" \
        "${CONFIGURE_OPTIONS[@]}" \
        CFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=." \
        CXXFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=."
else
    # When building native binutils with bootstrap toolchain, make sure it links
    # against the new glibc from sysroot instead of the system glibc
    DYNAMIC_LINKER=$(find "$SYSROOT/usr/lib" -name "ld-linux-*.so.*" -type f -printf "%f\n" | head -n 1)
    if [ -z "$DYNAMIC_LINKER" ]; then
        echo "Error: No dynamic linker found in $SYSROOT/usr/lib"
        exit 1
    fi

    "../src/configure" \
        "${CONFIGURE_OPTIONS[@]}" \
        CFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=." \
        CXXFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=." \
        LDFLAGS="-L$SYSROOT/usr/lib -Wl,-rpath=$SYSROOT/usr/lib -Wl,--dynamic-linker=$SYSROOT/usr/lib/$DYNAMIC_LINKER"
fi

echo "Building binutils..."
make -j$(nproc)

echo "Installing binutils..."
TMPDIR=$(mktemp -d)

make DESTDIR="$TMPDIR" install

echo "Setting timestamps to $SOURCE_DATE_EPOCH..."
find "$TMPDIR" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} \;

# Replace hardlinks with copies in $TARGET/bin
if [ -d "$TMPDIR/$TARGET/bin" ]; then
    echo "Replacing hardlinks with copies..."
    cd "$TMPDIR/$TARGET/bin"
    for tool in *; do
        if [ -f "$tool" ] && [ -f "../../bin/$TARGET-$tool" ]; then
            if [ "$(stat -c %i "$tool")" = "$(stat -c %i "../../bin/$TARGET-$tool")" ]; then
                echo "Replacing hardlink: $tool"
                rm "$tool"
                cp --preserve=timestamps "../../bin/$TARGET-$tool" "$tool"
            fi
        fi
    done
fi

cp -a "$TMPDIR"/* "$PREFIX"/

rm -rf "$TMPDIR"

echo "Binutils installed to $PREFIX"
