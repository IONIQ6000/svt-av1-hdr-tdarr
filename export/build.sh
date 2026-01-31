#!/bin/bash
# Build script for Tdarr with SVT-AV1-HDR

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

IMAGE_NAME="tdarr-svt-av1-hdr"
IMAGE_TAG="latest"

echo "=========================================="
echo "Building Tdarr with SVT-AV1-HDR"
echo "=========================================="
echo ""
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

# Check if podman or docker is available
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
else
    echo "Error: Neither podman nor docker found!"
    exit 1
fi

echo "Using container runtime: $CONTAINER_CMD"
echo ""

# Build the image
echo "Building image..."
$CONTAINER_CMD build \
    --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
    --file Dockerfile \
    .

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="
echo ""
echo "To verify SVT-AV1-HDR is available:"
echo "  $CONTAINER_CMD run --rm ${IMAGE_NAME}:${IMAGE_TAG} ffmpeg-svt-av1-hdr -encoders 2>/dev/null | grep svt"
echo ""
echo "To start Tdarr with the custom image:"
echo "  podman-compose up -d"
echo ""
