#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_ROOT="$(dirname "$SCRIPT_DIR")"
CLEAN_SOURCES=false

source "$SCRIPT_DIR/common.sh"

for arg in "$@"; do
    case $arg in
        --build-root=*)
            BUILD_ROOT="${arg#*=}"
            ;;
        --clean)
            CLEAN_SOURCES=true
            ;;
    esac
done

SRC_DIR="$BUILD_ROOT/src"
PKG_DIR="$BUILD_ROOT/pkg"

mkdir -p "$SRC_DIR" "$PKG_DIR"

if [ "$CLEAN_SOURCES" = true ]; then
    echo "Deleting $SRC_DIR/gcc-$GCC_VERSION"
    rm -rf "$SRC_DIR/gcc-$GCC_VERSION"

    echo "Deleting $SRC_DIR/binutils-$BINUTILS_VERSION"
    rm -rf "$SRC_DIR/binutils-$BINUTILS_VERSION"

    echo "Deleting $SRC_DIR/glibc-$GLIBC_VERSION"
    rm -rf "$SRC_DIR/glibc-$GLIBC_VERSION"

    echo "Deleting $SRC_DIR/linux-$LINUX_VERSION"
    rm -rf "$SRC_DIR/linux-$LINUX_VERSION"
fi

download() {
    local url="$1"
    local output="$2"
    local expected_sha256="$3"
    local src="$4"
    local checksum_ok=false
    local skip_checksum=false

    # Check if this is a placeholder checksum
    if [ "$expected_sha256" = "placeholder" ]; then
        echo "WARNING: Placeholder checksum for $(basename $output). Skipping checksum verification."
        skip_checksum=true
        checksum_ok=true
    fi

    # Check if file exists and verify checksum
    if [ -f "$output" ]; then
        if [ "$skip_checksum" = "true" ]; then
            echo "File $(basename $output) exists. Skipping checksum verification."
        else
            echo -n Verifying "$(basename $output)..."
            if echo "$expected_sha256 $output" | sha256sum -c - &>/dev/null; then
                echo " verified"
                checksum_ok=true
            else
                echo
                echo "Checksum mismatch for $(basename $output)! Re-downloading..."
                rm -f "$output"
                # Remove extracted directory if it exists
                if [ -d "$SRC_DIR/$src" ]; then
                    echo "Removing $SRC_DIR/$src..."
                    rm -rf "$SRC_DIR/$src"
                fi
            fi
        fi
    fi

    if ! [ -f "$output" ]; then
        echo "Downloading $url..."
        curl -L "$url" -o "$output"

        if [ "$skip_checksum" = "false" ]; then
            echo "Download complete. Verifying checksum..."
            if ! echo "$expected_sha256 $output" | sha256sum -c -; then
                echo "ERROR: Checksum verification failed for $(basename $output)!"
                rm -f "$output"
                exit 1
            fi
            echo "Checksum verified."
        else
            echo "Download complete. Checksum verification skipped."
        fi
    fi

    if [ -d "$SRC_DIR/$src" ]; then
        echo "Skipping $SRC_DIR/$src. Already extracted."
    else
        echo "Extracting $(basename $output)..."
        tar -xf "$output" -C "$SRC_DIR"
    fi
}

GCC_URL="https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz"
BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.gz"
GLIBC_URL="https://ftp.gnu.org/gnu/glibc/glibc-$GLIBC_VERSION.tar.gz"
LINUX_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$LINUX_VERSION.tar.gz"

download "$BINUTILS_URL" "$PKG_DIR/binutils-$BINUTILS_VERSION.tar.gz" "$BINUTILS_SHA256" "binutils-$BINUTILS_VERSION"
download "$GLIBC_URL" "$PKG_DIR/glibc-$GLIBC_VERSION.tar.gz" "$GLIBC_SHA256" "glibc-$GLIBC_VERSION"
download "$LINUX_URL" "$PKG_DIR/linux-$LINUX_VERSION.tar.gz" "$LINUX_SHA256" "linux-$LINUX_VERSION"
download "$GCC_URL" "$PKG_DIR/gcc-$GCC_VERSION.tar.gz" "$GCC_SHA256" "gcc-$GCC_VERSION"

# GCC dependencies
cd "$SRC_DIR/gcc-$GCC_VERSION"
./contrib/download_prerequisites
cd - > /dev/null

echo "All sources downloaded and extracted successfully."
