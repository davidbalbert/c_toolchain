#!/bin/bash
set -euo pipefail

# Replace binutils hardlinks with copies in installed toolchain
# Usage: replace-binutils-hardlinks.sh TMPDIR TRIPLE

if [ $# -ne 2 ]; then
    echo "Usage: $0 TMPDIR TRIPLE" >&2
    exit 1
fi

TMPDIR="$1"
TRIPLE="$2"

if [ -d "$TMPDIR/$TRIPLE/bin" ]; then
    cd "$TMPDIR/$TRIPLE/bin"
    for tool in *; do
        if [ -f "$tool" ] && [ -f "../../bin/$TRIPLE-$tool" ]; then
            if [ "$(stat -c %i "$tool")" = "$(stat -c %i "../../bin/$TRIPLE-$tool")" ]; then
                echo "Replacing hardlink: $tool"
                rm "$tool"
                cp --preserve=timestamps "../../bin/$TRIPLE-$tool" "$tool"
            fi
        fi
    done
fi
