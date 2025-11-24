#!/bin/bash
# Build script for Vicohome Bridge add-on
# Handles architecture mapping automatically

set -e

# Get the target architecture (default to current system)
TARGET_ARCH="${1:-$(uname -m)}"

# Map architecture names
case "$TARGET_ARCH" in
  x86_64)
    TARGET_ARCH="amd64"
    HA_ARCH="amd64"
    ;;
  amd64)
    HA_ARCH="amd64"
    ;;
  aarch64|arm64)
    TARGET_ARCH="arm64"
    HA_ARCH="aarch64"
    ;;
  *)
    echo "Unsupported architecture: $TARGET_ARCH"
    exit 1
    ;;
esac

echo "Building for architecture: $TARGET_ARCH (HA: $HA_ARCH)"

# Build the Docker image
docker buildx build \
  --platform linux/${TARGET_ARCH} \
  --build-arg TARGETARCH=${TARGET_ARCH} \
  --build-arg HA_ARCH=${HA_ARCH} \
  -t vicohome-bridge:${TARGET_ARCH} \
  -f Dockerfile \
  .

echo "Build complete! Image: vicohome-bridge:${TARGET_ARCH}"

