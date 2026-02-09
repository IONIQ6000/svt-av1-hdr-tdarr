#!/bin/bash
# =============================================================================
# Setup script for av1an + SVT-AV1-HDR on Fedora/Aurora (inside toolbox/distrobox)
# =============================================================================
#
# BASED ON: Auto-Boost-Av1an-Linux approach (adapted for Fedora)
#
# PREREQUISITES:
#   1. Create a toolbox: toolbox create encoding
#   2. Enter it: toolbox enter encoding
#   3. Run this script: sudo ./setup-av1an-svt-hdr.sh
#
# WHAT THIS INSTALLS:
#   - VapourSynth (from system packages)
#   - FFMS2 as VapourSynth source plugin
#   - SVT-AV1-HDR encoder (psychovisually optimized for HDR)
#   - av1an (parallel encoding framework)
#   - FFmpeg with SVT-AV1-HDR support
#   - mkvtoolnix for chunk concatenation
#
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "============================================"
echo "  av1an + SVT-AV1-HDR Setup for Fedora"
echo "============================================"
echo ""

# =============================================================================
# STEP 1: Install base dependencies
# =============================================================================
log_info "[1/7] Installing base dependencies..."
sudo dnf install -y \
    gcc gcc-c++ make cmake nasm git curl \
    autoconf automake libtool pkg-config \
    python3-devel python3-pip \
    zlib-devel \
    mkvtoolnix

# =============================================================================
# STEP 2: Install VapourSynth from system packages
# =============================================================================
log_info "[2/7] Installing VapourSynth from system packages..."

# Install VapourSynth and its tools
sudo dnf install -y \
    vapoursynth \
    vapoursynth-libs \
    vapoursynth-devel \
    vapoursynth-tools \
    python3-vapoursynth

# Enable COPR for additional VapourSynth plugins
log_info "Enabling flawlessmedia COPR repository..."
sudo dnf copr enable -y flawlessmedia/av-rpm 2>/dev/null || true

# Try to install L-SMASH plugin from COPR
log_info "Attempting to install vapoursynth-plugin-l-smash from COPR..."
sudo dnf install -y vapoursynth-plugin-l-smash 2>/dev/null || {
    log_warn "L-SMASH plugin not available from COPR, will compile FFMS2 instead"
}

# =============================================================================
# STEP 3: Build FFMS2 from source and link to VapourSynth
# =============================================================================
log_info "[3/7] Building FFMS2 plugin from source..."

# Get VapourSynth plugin path
VS_PLUGIN_PATH=$(pkg-config --variable=libdir vapoursynth 2>/dev/null)/vapoursynth || VS_PLUGIN_PATH="/usr/lib64/vapoursynth"
sudo mkdir -p "$VS_PLUGIN_PATH"

# Install FFMS2 dependencies
sudo dnf install -y ffmpeg-devel ffmpeg-libs || true

mkdir -p /tmp/build_tmp
cd /tmp/build_tmp

rm -rf ffms2
# Use tag 5.0 for compatibility with modern FFmpeg
git clone --branch 5.0 --depth 1 https://github.com/FFMS/ffms2.git
cd ffms2

./autogen.sh
./configure --enable-shared --prefix=/usr/local
make -j$(nproc)
sudo make install

# CRITICAL: Symlink FFMS2 to VapourSynth plugin directory
if [ -f "/usr/local/lib/libffms2.so" ]; then
    log_info "Linking FFMS2 to VapourSynth plugin folder: $VS_PLUGIN_PATH"
    sudo ln -sf "/usr/local/lib/libffms2.so" "$VS_PLUGIN_PATH/libffms2.so"
fi

sudo ldconfig

cd /tmp/build_tmp
log_info "FFMS2 installed and linked!"

# =============================================================================
# STEP 4: Install Rust (required for av1an)
# =============================================================================
log_info "[4/7] Installing Rust..."
if ! command -v cargo &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
source "$HOME/.cargo/env"

# =============================================================================
# STEP 5: Build SVT-AV1-HDR from source
# =============================================================================
log_info "[5/7] Building SVT-AV1-HDR..."
cd /tmp/build_tmp
rm -rf svt-av1-hdr
git clone --depth 1 https://github.com/juliobbv-p/svt-av1-hdr.git
cd svt-av1-hdr
mkdir -p Build/linux && cd Build/linux
cmake ../.. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/.local
make -j$(nproc)
make install
cd /tmp/build_tmp

# Set library path immediately
export LD_LIBRARY_PATH="$HOME/.local/lib64:$LD_LIBRARY_PATH"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

log_info "SVT-AV1-HDR version:"
$HOME/.local/bin/SvtAv1EncApp --version 2>&1 | head -1

# =============================================================================
# STEP 6: Install av1an via cargo (from rust-av fork)
# =============================================================================
log_info "[6/7] Installing av1an..."
source "$HOME/.cargo/env"

# Set paths for cargo to find VapourSynth
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$(pkg-config --variable=pc_path pkg-config):$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
export LIBRARY_PATH="/usr/local/lib:$LIBRARY_PATH"

cargo install --git https://github.com/rust-av/Av1an.git --bin av1an 2>&1 | tail -20

log_info "av1an installed!"

# =============================================================================
# STEP 7: Download FFmpeg with SVT-AV1-HDR support
# =============================================================================
log_info "[7/7] Downloading FFmpeg with SVT-AV1-HDR..."
mkdir -p $HOME/.local/bin
curl -L "https://github.com/QuickFatHedgehog/FFmpeg-Builds-SVT-AV1-HDR/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz" -o /tmp/ffmpeg.tar.xz
tar -xf /tmp/ffmpeg.tar.xz --strip-components=1 -C $HOME/.local
rm /tmp/ffmpeg.tar.xz

log_info "FFmpeg installed!"

# =============================================================================
# Configure shell environment
# =============================================================================
log_info "Configuring shell environment..."

# Determine shell config file
SHELL_RC="$HOME/.bashrc"
[ -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.zshrc"

# Get the actual VapourSynth plugin path
VS_PLUGIN_PATH_FINAL=$(pkg-config --variable=libdir vapoursynth 2>/dev/null)/vapoursynth || VS_PLUGIN_PATH_FINAL="/usr/lib64/vapoursynth"

# Add environment variables if not already present
if ! grep -q "SVT-AV1-HDR paths" "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" << SHELLCONFIG

# =============================================================================
# SVT-AV1-HDR + av1an environment
# =============================================================================
export LD_LIBRARY_PATH="\$HOME/.local/lib64:/usr/local/lib:\$LD_LIBRARY_PATH"
export PATH="\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH"
export VAPOURSYNTH_PLUGIN_PATH="$VS_PLUGIN_PATH_FINAL:/usr/local/lib/vapoursynth:\$HOME/.local/lib/vapoursynth"
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:\$PKG_CONFIG_PATH"
SHELLCONFIG
    log_info "Added environment variables to $SHELL_RC"
else
    log_info "Environment variables already configured"
fi

# Apply immediately
export LD_LIBRARY_PATH="$HOME/.local/lib64:/usr/local/lib:$LD_LIBRARY_PATH"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export VAPOURSYNTH_PLUGIN_PATH="$VS_PLUGIN_PATH_FINAL:/usr/local/lib/vapoursynth:$HOME/.local/lib/vapoursynth"

# Cleanup
rm -rf /tmp/build_tmp

# =============================================================================
# VERIFICATION
# =============================================================================
echo ""
echo "============================================"
echo "  VERIFICATION"
echo "============================================"

# Verify VapourSynth
echo ""
log_info "VapourSynth:"
vspipe --version 2>&1 | head -1 || log_warn "vspipe not found, but may still work via Python"

# Verify VapourSynth plugins (CRITICAL)
echo ""
log_info "VapourSynth plugins:"
python3 - <<'PY'
import vapoursynth as vs
core = vs.core
plugins = [p.namespace for p in core.plugins()]
print(f"  Loaded plugins: {plugins}")
print(f"  has ffms2: {hasattr(core, 'ffms2')}")
print(f"  has lsmas: {hasattr(core, 'lsmas')}")
if hasattr(core, 'ffms2') or hasattr(core, 'lsmas'):
    print("  SUCCESS: Source plugin available!")
else:
    print("  WARNING: No source plugin found - checking plugin path...")
    import os
    plugin_path = os.environ.get('VAPOURSYNTH_PLUGIN_PATH', '')
    print(f"  VAPOURSYNTH_PLUGIN_PATH: {plugin_path}")
PY

# Verify encoder
echo ""
log_info "SVT-AV1-HDR encoder:"
$HOME/.local/bin/SvtAv1EncApp --version 2>&1 | head -1

# Verify av1an
echo ""
log_info "av1an:"
$HOME/.cargo/bin/av1an --version 2>&1 | head -1 || echo "av1an installed"

echo ""
echo "============================================"
echo "  SETUP COMPLETE!"
echo "============================================"
echo ""
echo "IMPORTANT: Restart your shell or run:"
echo "  source $SHELL_RC"
echo ""
echo "Then verify with:"
echo "  ./verify-av1an-setup.sh"
echo ""
echo "Encode with:"
echo "  ./av1an-svt-hdr-encode.sh input.mkv output.mkv"
echo ""
echo "============================================"
