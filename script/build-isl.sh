#!/bin/bash
set -euo pipefail

# Print usage information
print_usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Build ISL (Integer Set Library) for the specified target architecture."
    echo ""
    echo "Options:"
    echo "  --build-root=DIR     Set the build root directory (default: project root)"
    echo "  --host=TRIPLE        Set the host architecture triple"
    echo "  --target=TRIPLE      Set the target architecture triple"
    echo "  --clean              Clean the build directory before building"
    echo "  --bootstrap          Build bootstrap ISL using the system compiler"
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
else
    BUILD_DIR="$BUILD_ROOT/build/$HOST/$TARGET-gcc-$GCC_VERSION"
    PREFIX="$BUILD_ROOT/out/$HOST/$TARGET-gcc-$GCC_VERSION/toolchain"
fi

ISL_BUILD_DIR="$BUILD_DIR/isl"

if [ "$CLEAN_BUILD" = true ] && [ -d "$ISL_BUILD_DIR" ]; then
    echo "Cleaning $ISL_BUILD_DIR..."
    rm -rf "$ISL_BUILD_DIR"
fi

mkdir -p "$ISL_BUILD_DIR"
cd "$ISL_BUILD_DIR"

# Set reproducibility environment variables
export LC_ALL=C
export SOURCE_DATE_EPOCH=1

echo "Building isl-$ISL_VERSION"
echo "Host:      $HOST"
echo "Target:    $TARGET"
echo "Bootstrap: $BOOTSTRAP"
echo "Source:    $SRC_DIR/isl-$ISL_VERSION"
echo "Build:     $ISL_BUILD_DIR"
echo "Prefix:    $PREFIX"
echo

echo "Configuring ISL..."
"$SRC_DIR/isl-$ISL_VERSION/configure" \
    --build="$HOST" \
    --host="$HOST" \
    --prefix="$PREFIX" \
    --disable-shared \
    --enable-static \
    --with-gmp-prefix="$PREFIX" \
    CFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=." \
    CXXFLAGS="-g0 -O2 -ffile-prefix-map=$SRC_DIR=. -ffile-prefix-map=$BUILD_DIR=."

echo "Building ISL..."
make -j$(nproc)

echo "Installing ISL..."
make install

echo "ISL installed to $PREFIX"
