#!/bin/bash
# SVT-AV1-HDR Direct Encoder Script
# Uses FFmpeg with libsvtav1 for HDR content encoding

set -e

# === Configuration ===
CRF="${CRF:-28}"
PRESET="${PRESET:-6}"

# === Environment Setup ===
export LD_LIBRARY_PATH="$HOME/.local/lib64:$LD_LIBRARY_PATH"
export PATH="$HOME/.local/bin:$PATH"

# === Input Validation ===
if [ $# -lt 2 ]; then
    echo "Usage: $0 <input.mkv> <output.mkv>"
    echo ""
    echo "Environment variables:"
    echo "  CRF=28      Quality (lower = better, 18-35 typical)"
    echo "  PRESET=6    Speed (0=slowest/best, 13=fastest)"
    echo ""
    echo "Example:"
    echo "  CRF=26 PRESET=5 $0 movie.mkv movie-av1.mkv"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"

if [ ! -f "$INPUT" ]; then
    echo "Error: Input file not found: $INPUT"
    exit 1
fi

# === Verify FFmpeg has libsvtav1 ===
if ! ffmpeg -encoders 2>/dev/null | grep -q libsvtav1; then
    echo "Error: FFmpeg does not have libsvtav1 support"
    echo "Make sure you're using the correct FFmpeg binary"
    exit 1
fi

# === Display Settings ===
echo "=== SVT-AV1-HDR Encode ==="
echo "Input:  $INPUT"
echo "Output: $OUTPUT"
echo "CRF:    $CRF"
echo "Preset: $PRESET"
echo ""

# Check encoder version
echo "=== Encoder Info ==="
ffmpeg -hide_banner -h encoder=libsvtav1 2>/dev/null | head -5
echo ""

# === Encode ===
echo "=== Starting Encode ==="
echo "Press 'q' to stop, '?' for help during encoding"
echo ""

ffmpeg -i "$INPUT" \
    -map 0:v:0 \
    -map 0:a \
    -map 0:s? \
    -c:v libsvtav1 \
    -crf "$CRF" \
    -preset "$PRESET" \
    -svtav1-params "tune=0:enable-variance-boost=1:variance-boost-strength=2:variance-octile=5:variance-boost-curve=3:sharpness=1:qp-scale-compress-strength=1" \
    -pix_fmt yuv420p10le \
    -color_primaries bt2020 \
    -color_trc smpte2084 \
    -colorspace bt2020nc \
    -c:a copy \
    -c:s copy \
    "$OUTPUT"

echo ""
echo "=== Encode Complete ==="
echo "Output: $OUTPUT"
ls -lh "$OUTPUT"
