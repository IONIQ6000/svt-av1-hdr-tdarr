#!/bin/bash
# =============================================================================
# Verification Script for av1an + SVT-AV1-HDR Setup
# =============================================================================
# Run this after setup-av1an-svt-hdr.sh to verify everything works
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "============================================"
echo "  av1an + SVT-AV1-HDR Verification"
echo "============================================"
echo ""

# Set environment
export LD_LIBRARY_PATH="$HOME/.local/lib64:/usr/local/lib:$LD_LIBRARY_PATH"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export VAPOURSYNTH_PLUGIN_PATH="/usr/local/lib/vapoursynth:$HOME/.local/lib/vapoursynth"

ERRORS=0

# 1. VapourSynth binary
echo "[1/6] Checking vspipe..."
if command -v vspipe &>/dev/null; then
    pass "vspipe: $(vspipe --version 2>&1 | head -1)"
else
    fail "vspipe not found!"
    ((ERRORS++))
fi

# 2. Python VapourSynth import
echo ""
echo "[2/6] Checking Python VapourSynth module..."
if python3 -c "import vapoursynth; print(f'VapourSynth {vapoursynth.__version__}')" 2>/dev/null; then
    pass "Python VapourSynth module works"
else
    fail "Cannot import vapoursynth in Python"
    ((ERRORS++))
fi

# 3. FFMS2 Plugin (CRITICAL)
echo ""
echo "[3/6] Checking VapourSynth FFMS2 plugin..."
FFMS2_CHECK=$(python3 -c "
import vapoursynth as vs
core = vs.core
if hasattr(core, 'ffms2'):
    print('OK')
else:
    print('MISSING')
" 2>/dev/null || echo "ERROR")

if [ "$FFMS2_CHECK" == "OK" ]; then
    pass "FFMS2 plugin is loaded"
else
    fail "FFMS2 plugin NOT found - av1an will not work!"
    echo "    Check: ls -la /usr/local/lib/vapoursynth/"
    echo "    Should contain: libffms2.so"
    ((ERRORS++))
fi

# 4. SVT-AV1-HDR Encoder
echo ""
echo "[4/6] Checking SVT-AV1-HDR encoder..."
if SvtAv1EncApp --version 2>&1 | grep -q "SVT-AV1-HDR"; then
    pass "SvtAv1EncApp: $(SvtAv1EncApp --version 2>&1 | head -1)"
else
    fail "SVT-AV1-HDR not found or not working"
    echo "    Check: export LD_LIBRARY_PATH=\"\$HOME/.local/lib64:\$LD_LIBRARY_PATH\""
    ((ERRORS++))
fi

# 5. av1an
echo ""
echo "[5/6] Checking av1an..."
if command -v av1an &>/dev/null; then
    pass "av1an: $(av1an --version 2>&1 | head -1 || echo 'installed')"
else
    fail "av1an not found!"
    ((ERRORS++))
fi

# 6. FFmpeg with libsvtav1
echo ""
echo "[6/6] Checking FFmpeg SVT-AV1 support..."
if ffmpeg -encoders 2>/dev/null | grep -q "libsvtav1"; then
    pass "FFmpeg has libsvtav1 encoder"
else
    warn "FFmpeg may not have libsvtav1 (could still work with av1an)"
fi

# Summary
echo ""
echo "============================================"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}  All checks passed!${NC}"
    echo "============================================"
    echo ""
    echo "You can now encode with:"
    echo "  ./av1an-svt-hdr-encode.sh input.mkv output.mkv"
else
    echo -e "${RED}  $ERRORS check(s) failed!${NC}"
    echo "============================================"
    echo ""
    echo "Re-run setup:"
    echo "  sudo ./setup-av1an-svt-hdr.sh"
    echo ""
    echo "Then restart your shell:"
    echo "  source ~/.bashrc"
    exit 1
fi
