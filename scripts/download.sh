#!/bin/bash
set -euo pipefail

# Base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Default directories
DEFAULT_SRC_DIR=
DEFAULT_PKG_DIR=

# Parse command line options
SRC_DIR="$ROOT_DIR/src"
PKG_DIR="$ROOT_DIR/pkg"

for arg in "$@"; do
    case $arg in
        --src-dir=*)
            SRC_DIR="${arg#*=}"
            ;;
        --pkg-dir=*)
            PKG_DIR="${arg#*=}"
            ;;
    esac
done

# Create directories if they don't exist
mkdir -p "$SRC_DIR" "$PKG_DIR"

# Package versions
GCC_VERSION="15.1.0"
BINUTILS_VERSION="2.44"
GLIBC_VERSION="2.41"
LINUX_VERSION="6.6.89"

# URLs
GCC_URL="https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz"
BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.gz"
GLIBC_URL="https://ftp.gnu.org/gnu/glibc/glibc-$GLIBC_VERSION.tar.gz"
LINUX_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$LINUX_VERSION.tar.gz"

# Expected SHA256 checksums
# Note: These are placeholders - need to be updated with actual checksums
GCC_SHA256="placeholder"
BINUTILS_SHA256="placeholder"
GLIBC_SHA256="placeholder"
LINUX_SHA256="placeholder"

# Download function
download() {
    local url="$1"
    local output="$2"
    local expected_sha256="$3"
    local name="$4"
    
    echo "Downloading $name from $url..."
    if [ -f "$output" ]; then
        echo "$name already downloaded, checking checksum..."
    else
        curl -L "$url" -o "$output"
        echo "Download complete."
    fi
    
    if [ "$expected_sha256" != "placeholder" ]; then
        echo "Verifying checksum..."
        echo "$expected_sha256 $output" | sha256sum -c -
        echo "Checksum verified."
    else
        echo "WARNING: Checksum verification skipped for $name. Update script with actual checksums."
    fi
}

# Download all sources
download "$GCC_URL" "$PKG_DIR/gcc-$GCC_VERSION.tar.gz" "$GCC_SHA256" "GCC $GCC_VERSION"
download "$BINUTILS_URL" "$PKG_DIR/binutils-$BINUTILS_VERSION.tar.gz" "$BINUTILS_SHA256" "Binutils $BINUTILS_VERSION"
download "$GLIBC_URL" "$PKG_DIR/glibc-$GLIBC_VERSION.tar.gz" "$GLIBC_SHA256" "glibc $GLIBC_VERSION"
download "$LINUX_URL" "$PKG_DIR/linux-$LINUX_VERSION.tar.gz" "$LINUX_SHA256" "Linux kernel $LINUX_VERSION"

# Extract tarballs
for tarball in "$PKG_DIR"/*.tar.gz; do
    if [ -f "$tarball" ]; then
        echo "Extracting $(basename "$tarball")..."
        tar -xzf "$tarball" -C "$SRC_DIR"
    fi
done

echo "All sources downloaded and extracted successfully."
