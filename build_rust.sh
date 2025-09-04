#!/bin/bash

set -e

# Navigate to the rust_core directory
cd "$(dirname "$0")/rust_core"

# Clean previous builds to ensure we're building fresh
cargo clean

# Build the Rust library for release (static library only)
cargo build --release --target aarch64-apple-darwin

# Verify the static library was created
if [ ! -f "target/aarch64-apple-darwin/release/librust_core.a" ]; then
    echo "Error: Static library not found!"
    exit 1
fi

# Create the target directory in Xcode's build products if it doesn't exist
XCODE_BUILD_DIR="${BUILT_PRODUCTS_DIR:-../target/xcode}"
mkdir -p "$XCODE_BUILD_DIR"

# Copy the static library to where Xcode expects it
cp target/aarch64-apple-darwin/release/librust_core.a "$XCODE_BUILD_DIR/"

echo "Rust static library built and copied successfully"
echo "Library location: $XCODE_BUILD_DIR/librust_core.a"
