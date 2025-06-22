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

GCC_BUILD_DIR="$BUILD_DIR/gcc/build"

if [ "$CLEAN_BUILD" = true ] && [ -d "$BUILD_DIR/gcc" ]; then
    echo "Cleaning $BUILD_DIR/gcc..."
    rm -rf "$BUILD_DIR/gcc"
fi

mkdir -p "$GCC_BUILD_DIR"

# Create symlink to source directory
ln -sfn "$SRC_DIR/gcc-$GCC_VERSION" "$BUILD_DIR/gcc/src"
mkdir -p "$PREFIX"
mkdir -p "$SYSROOT"

if [ "$BOOTSTRAP" == "true" ]; then
    ln -sfn "../../../$HOST/$HOST-gcc-$GCC_VERSION/sysroot" "$PREFIX/sysroot"
else
    ln -sfn "../sysroot" "$PREFIX/sysroot"
fi

if [ ! -x "$PREFIX/bin/$TARGET-as" ]; then
    echo "Error: Binutils not found in $PREFIX"
    echo "Please build binutils first using scripts/build-binutils.sh"
    exit 1
fi

# Set reproducibility environment variables
export LC_ALL=C.UTF-8

TIMESTAMP_FILE="$SRC_DIR/gcc-$GCC_VERSION/.timestamp"
if [ -f "$TIMESTAMP_FILE" ]; then
    source "$TIMESTAMP_FILE"
else
    echo "Warning: No timestamp file found for gcc"
    export SOURCE_DATE_EPOCH=1
fi

if [ "$CROSS" = false ]; then
    PATH="$BOOTSTRAP_PREFIX/bin:$PATH"
fi
export PATH="$NATIVE_PREFIX/bin:$PATH"

echo "Building gcc-$GCC_VERSION"
echo "Host:    $HOST"
echo "Target:  $TARGET"
echo "Source:  $SRC_DIR/gcc-$GCC_VERSION"
echo "Build:   $GCC_BUILD_DIR"
echo "Prefix:  $PREFIX"
echo "Sysroot: $SYSROOT"
echo "Path:    $PATH"
echo

cd "$GCC_BUILD_DIR"

CONFIGURE_OPTIONS=(
    "--host=$HOST"
    "--target=$TARGET"
    "--prefix="
    "--with-sysroot=/sysroot"
    "--with-build-sysroot=$SYSROOT"
    "--enable-default-pie"
    "--enable-default-ssp"
    "--disable-multilib"
    "--disable-bootstrap"
    "--enable-languages=c,c++"
)

if [ "$BOOTSTRAP" == "true" ]; then
    CONFIGURE_OPTIONS+=("--with-glibc-version=$GLIBC_VERSION")
    CONFIGURE_OPTIONS+=("--with-newlib")
    CONFIGURE_OPTIONS+=("--disable-nls")
    CONFIGURE_OPTIONS+=("--disable-shared")
    CONFIGURE_OPTIONS+=("--disable-threads")
    CONFIGURE_OPTIONS+=("--disable-libatomic")
    CONFIGURE_OPTIONS+=("--disable-libgomp")
    CONFIGURE_OPTIONS+=("--disable-libquadmath")
    CONFIGURE_OPTIONS+=("--disable-libssp")
    CONFIGURE_OPTIONS+=("--disable-libvtv")
    CONFIGURE_OPTIONS+=("--disable-libstdcxx")
    CONFIGURE_OPTIONS+=("--without-headers")
    CONFIGURE_OPTIONS+=("--with-gxx-include-dir=/sysroot/usr/include/c++/$GCC_VERSION")
else
    CONFIGURE_OPTIONS+=("--enable-host-pie")
    CONFIGURE_OPTIONS+=("--disable-fixincludes")

    if [ ! -x "$NATIVE_PREFIX/bin/$TARGET-gcc" ]; then
        CONFIGURE_OPTIONS+=("--with-build-time-tools=$NATIVE_PREFIX/$TARGET/bin")
    fi
fi

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

    export CFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=."
    export CXXFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=."
    export LDFLAGS="-L$SYSROOT/usr/lib -Wl,-rpath=$SYSROOT/usr/lib -Wl,--dynamic-linker=$SYSROOT/usr/lib/$DYNAMIC_LINKER"

    "../src/configure" \
        "${CONFIGURE_OPTIONS[@]}"
fi

echo "Building GCC..."
make -j$(nproc) configure-gcc

# Remove --with-build-sysroot= from configargs.h so that the path isn't hardcoded
# into the binary. Helps with reproducibility.
sed -i 's/ --with-build-sysroot=[^ ]*//' gcc/configargs.h

make -j$(nproc)

echo "Installing GCC..."
TMPDIR=$(mktemp -d)

make DESTDIR="$TMPDIR" install

find "$TMPDIR" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} \;

cp -a "$TMPDIR"/* "$PREFIX"/
rm -rf "$TMPDIR"

echo "GCC installed to $PREFIX"
