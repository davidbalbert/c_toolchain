#!/bin/bash
set -euo pipefail

# Base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_ROOT="$(dirname "$SCRIPT_DIR")"

for arg in "$@"; do
    case $arg in
        --build-root=*)
            BUILD_ROOT="${arg#*=}"
            ;;
    esac
done

# Define paths based on build root
SRC_DIR="$BUILD_ROOT/src"
PKG_DIR="$BUILD_ROOT/pkg"

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
GCC_SHA256="51b9919ea69c980d7a381db95d4be27edf73b21254eb13d752a08003b4d013b1"
BINUTILS_SHA256="0cdd76777a0dfd3dd3a63f215f030208ddb91c2361d2bcc02acec0f1c16b6a2e"
GLIBC_SHA256="c7be6e25eeaf4b956f5d4d56a04d23e4db453fc07760f872903bb61a49519b80"
LINUX_SHA256="724f68742eeccf26e090f03dd8dfbf9c159d65f91d59b049e41f996fa41d9bc1"

# Download function
download() {
    local url="$1"
    local output="$2"
    local expected_sha256="$3"
    local src="$4"
    local checksum_ok=false

    # Check if file exists and verify checksum
    if [ -f "$output" ]; then
        echo -n "$(basename $output) already downloaded, verifying checksum..."
        if echo "$expected_sha256 $output" | sha256sum -c - &>/dev/null; then
            echo " verified"
            checksum_ok=true
        else
            echo
            echo "Checksum mismatch for $(basename $output)! Re-downloading..."
            rm -f "$output"
            # Remove extracted directory if it exists
            if [ -d "$SRC_DIR/$src" ]; then
                echo "Removing $SRC_DIR/src..."
                rm -rf "$SRC_DIR/$src"
            fi
        fi
    fi

    # Download if needed
    if [ "$checksum_ok" != "true" ]; then
        echo "Downloading $url..."
        curl -L "$url" -o "$output"
        echo "Download complete. Verifying checksum..."

        # Verify checksum
        if ! echo "$expected_sha256 $output" | sha256sum -c -; then
            echo "ERROR: Checksum verification failed for $(basename $output)!"
            rm -f "$output"
            exit 1
        fi
        echo "Checksum verified."
    fi

    # Extract if needed
    if [ -d "$SRC_DIR/$src" ]; then
        echo "Skipping $SRC_DIR/$src. Already extracted."
    else
        echo "Extracting $(basename $output)..."
        tar -xzf "$output" -C "$SRC_DIR"
    fi
}

# Download and extract all sources
download "$GCC_URL" "$PKG_DIR/gcc-$GCC_VERSION.tar.gz" "$GCC_SHA256" "gcc-$GCC_VERSION"
download "$BINUTILS_URL" "$PKG_DIR/binutils-$BINUTILS_VERSION.tar.gz" "$BINUTILS_SHA256" "binutils-$BINUTILS_VERSION"
download "$GLIBC_URL" "$PKG_DIR/glibc-$GLIBC_VERSION.tar.gz" "$GLIBC_SHA256" "glibc-$GLIBC_VERSION"
download "$LINUX_URL" "$PKG_DIR/linux-$LINUX_VERSION.tar.gz" "$LINUX_SHA256" "linux-$LINUX_VERSION"

echo "All sources downloaded and extracted successfully."
