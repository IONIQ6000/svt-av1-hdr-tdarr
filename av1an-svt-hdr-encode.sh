#!/bin/bash
# =============================================================================
# av1an + SVT-AV1-HDR Encoder Script
# =============================================================================
# Encodes video using av1an for parallel chunking + SVT-AV1-HDR for quality
#
# Usage:
#   ./av1an-svt-hdr-encode.sh input.mkv output.mkv
#   CRF=28 PRESET=6 WORKERS=2 ./av1an-svt-hdr-encode.sh input.mkv output.mkv
#
# Requirements (install via setup-av1an-svt-hdr.sh):
#   - SVT-AV1-HDR encoder
#   - av1an with VapourSynth + FFMS2 plugin (compiled from source)
#   - mkvtoolnix
# =============================================================================

set -e

# =============================================================================
# ENVIRONMENT SETUP (CRITICAL - must be set before any commands)
# =============================================================================
export LD_LIBRARY_PATH="$HOME/.local/lib64:/usr/local/lib:$LD_LIBRARY_PATH"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export VAPOURSYNTH_PLUGIN_PATH="/usr/local/lib/vapoursynth:$HOME/.local/lib/vapoursynth"
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

# =============================================================================
# CONFIGURATION
# =============================================================================
CRF="${CRF:-28}"
PRESET="${PRESET:-6}"
# Reduced default workers for 4K HDR memory safety
WORKERS="${WORKERS:-2}"
# Limit encoder thread pool per instance
LP="${LP:-4}"

# =============================================================================
# ARGUMENT PARSING
# =============================================================================
if [ $# -lt 2 ]; then
    echo "Usage: $0 <input.mkv> <output.mkv>"
    echo ""
    echo "Environment variables:"
    echo "  CRF=28        Quality (lower = better quality, range: 0-63, default: 28)"
    echo "  PRESET=6      Speed preset (0=slowest/best, 13=fastest, default: 6)"
    echo "  WORKERS=2     Parallel encoding workers (default: 2 for 4K HDR safety)"
    echo "  LP=4          Encoder thread pool per worker (default: 4)"
    echo ""
    echo "Examples:"
    echo "  $0 input.mkv output.mkv"
    echo "  CRF=30 PRESET=6 WORKERS=2 $0 input.mkv output.mkv"
    echo ""
    echo "SVT-AV1-HDR specific params (auto-enabled):"
    echo "  --tune 0                  Psychovisual optimization"
    echo "  --variance-boost-curve 3  HDR contrast preservation"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================
echo "============================================"
echo "  av1an + SVT-AV1-HDR Encoder"
echo "============================================"
echo ""

# Check input file
if [ ! -f "$INPUT" ]; then
    echo "ERROR: Input file not found: $INPUT"
    exit 1
fi

# Check SVT-AV1-HDR encoder
echo "[CHECK] SVT-AV1-HDR encoder..."
if ! SvtAv1EncApp --version 2>&1 | grep -q "SVT-AV1-HDR"; then
    echo ""
    echo "ERROR: SVT-AV1-HDR not found or library missing!"
    echo ""
    echo "Make sure LD_LIBRARY_PATH is set:"
    echo "  export LD_LIBRARY_PATH=\"\$HOME/.local/lib64:\$LD_LIBRARY_PATH\""
    echo ""
    echo "Or re-run setup: sudo ./setup-av1an-svt-hdr.sh"
    exit 1
fi
SvtAv1EncApp --version 2>&1 | head -1

# Check av1an
echo ""
echo "[CHECK] av1an..."
if ! command -v av1an &>/dev/null; then
    echo "ERROR: av1an not found!"
    exit 1
fi
echo "av1an found: $(which av1an)"

# Check VapourSynth with FFMS2 plugin (CRITICAL)
echo ""
echo "[CHECK] VapourSynth + FFMS2 plugin..."
VAPOURSYNTH_OK=$(python3 -c "
import vapoursynth as vs
core = vs.core
has_ffms2 = hasattr(core, 'ffms2')
print('OK' if has_ffms2 else 'MISSING')
" 2>/dev/null || echo "ERROR")

if [ "$VAPOURSYNTH_OK" != "OK" ]; then
    echo ""
    echo "ERROR: VapourSynth FFMS2 plugin not found!"
    echo ""
    echo "The setup script compiles FFMS2 from source and links it."
    echo "Re-run: sudo ./setup-av1an-svt-hdr.sh"
    echo ""
    echo "Then restart your shell: source ~/.bashrc"
    exit 1
fi
python3 -c "
import vapoursynth as vs
core = vs.core
print(f'  VapourSynth: {vs.__version__}')
print(f'  ffms2: {hasattr(core, \"ffms2\")}')
"

# =============================================================================
# ENCODING SETTINGS
# =============================================================================
echo ""
echo "============================================"
echo "  Encoding Settings"
echo "============================================"
echo "Input:   $INPUT"
echo "Output:  $OUTPUT"
echo "CRF:     $CRF"
echo "Preset:  $PRESET"
echo "Workers: $WORKERS"
echo "LP:      $LP (thread pool per worker)"
echo "Encoder: SVT-AV1-HDR"
echo ""

# SVT-AV1-HDR specific parameters
# --lp limits thread pool per encoder instance (prevents RAM exhaustion with 4K)
VIDEO_PARAMS="--crf ${CRF} --preset ${PRESET} --tune 0 --variance-boost-curve 3 --lp ${LP}"
echo "Video params: $VIDEO_PARAMS"

# HDR color metadata (bt2020 + PQ)
FFMPEG_PARAMS="-color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc"
echo "FFmpeg params: $FFMPEG_PARAMS"

# Create temp directory
TEMP_DIR=$(mktemp -d /tmp/av1an-XXXXXX)
echo "Temp dir: $TEMP_DIR"

# =============================================================================
# ENCODE
# =============================================================================
echo ""
echo "============================================"
echo "  Starting Encode"
echo "============================================"
echo "(Scene detection may take several minutes for large 4K files...)"
echo ""

# Key av1an parameters:
# --chunk-method ffms2    - Use our compiled FFMS2 plugin for chunking
# --split-method av-scenechange - av1an's built-in scene detection (no VapourSynth dep)
# -x 240                  - Fallback fixed split every 240 frames (~10sec at 24fps)
# --pix-format            - 10-bit for HDR
# --concat mkvmerge       - Use mkvmerge for reliable concatenation
av1an \
    -i "$INPUT" \
    -o "$OUTPUT" \
    -e svt-av1 \
    -v "$VIDEO_PARAMS" \
    --pix-format yuv420p10le \
    -w "$WORKERS" \
    --chunk-method ffms2 \
    --split-method av-scenechange \
    -x 240 \
    --concat mkvmerge \
    --temp "$TEMP_DIR" \
    -f "$FFMPEG_PARAMS" \
    -a "-c:a copy" \
    --verbose

# =============================================================================
# DONE
# =============================================================================
echo ""
echo "============================================"
echo "  Encode Complete!"
echo "============================================"
if [ -f "$OUTPUT" ]; then
    echo "Output: $OUTPUT"
    ls -lh "$OUTPUT"
    echo ""
    echo "Verify with:"
    echo "  ffprobe \"$OUTPUT\" 2>&1 | head -30"
else
    echo "WARNING: Output file not found!"
fi

# Cleanup temp (comment out to keep for debugging)
rm -rf "$TEMP_DIR"
