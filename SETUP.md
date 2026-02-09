# Complete Setup Guide: av1an + SVT-AV1-HDR on Fedora/Aurora

This guide documents the complete setup process for encoding HDR video using av1an with the SVT-AV1-HDR encoder on Fedora-based systems (including Aurora, Silverblue, Kinoite).

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Manual Installation](#manual-installation)
5. [Environment Configuration](#environment-configuration)
6. [Usage](#usage)
7. [Troubleshooting](#troubleshooting)
8. [Technical Details](#technical-details)

---

## Overview

### What This Setup Provides

| Tool | Purpose |
|------|---------|
| **SVT-AV1-HDR** | Psychovisually optimized AV1 encoder with HDR-specific enhancements |
| **av1an** | Splits video into chunks for parallel encoding (massive speedup) |
| **VapourSynth + L-SMASH** | Video processing framework + source plugin (required by av1an) |
| **FFmpeg** | Pre-built binary with SVT-AV1-HDR support |
| **mkvtoolnix** | Concatenates encoded chunks back together |

### Why Use a Toolbox/Distrobox?

On immutable systems (Aurora, Silverblue), you can't install packages to the base system. A toolbox provides a mutable Fedora container that:
- Has full `dnf` package management
- Shares your home directory
- Can access your files seamlessly

---

## Prerequisites

### System Requirements

- **OS**: Fedora 40+, Aurora, Silverblue, or any Fedora-based distro
- **RAM**: 16GB+ recommended (32GB+ for 4K)
- **CPU**: Multi-core recommended (av1an parallelizes across cores)
- **Disk**: ~50GB free for temp files during encoding

### Required Tools

```bash
# On immutable systems, install toolbox
rpm-ostree install toolbox  # or it may already be installed
```

---

## Quick Start

### 1. Create and Enter Toolbox

```bash
# Create a dedicated encoding toolbox
toolbox create encoding

# Enter it
toolbox enter encoding
```

### 2. Run Setup Script

```bash
# Clone or navigate to this repo
cd "/home/dark-moon/svt-av1-hdr tdarr"

# Run the automated setup
./setup-av1an-svt-hdr.sh
```

### 3. Restart Shell (CRITICAL!)

```bash
# Either exit and re-enter the toolbox
exit
toolbox enter encoding

# Or source the config directly
source ~/.bashrc
```

### 4. Verify Installation

```bash
# Check encoder
SvtAv1EncApp --version
# Should show: SVT-AV1-HDR ...

# Check VapourSynth
python3 -c "import vapoursynth as vs; c=vs.core; print('lsmas:', hasattr(c,'lsmas'))"
# Should show: lsmas: True
```

### 5. Encode!

```bash
./av1an-svt-hdr-encode.sh input.mkv output.mkv

# With custom settings
CRF=28 PRESET=6 WORKERS=8 ./av1an-svt-hdr-encode.sh input.mkv output.mkv
```

---

## Manual Installation

If the setup script fails or you want to understand each step:

### Step 1: Install Base Dependencies

```bash
sudo dnf install -y \
    gcc gcc-c++ make cmake nasm git curl \
    mkvtoolnix \
    python3-pip \
    vapoursynth-libs \
    python3-vapoursynth \
    vapoursynth-tools \
    ffms2
```

### Step 2: Install VapourSynth L-SMASH Plugin

This is **critical** - av1an requires a source plugin to open video files.

```bash
# Enable the COPR repository
sudo dnf copr enable -y flawlessmedia/av-rpm

# Install the L-SMASH plugin
sudo dnf install -y vapoursynth-plugin-l-smash
```

**Verify it works:**
```bash
python3 -c "import vapoursynth as vs; c=vs.core; print('lsmas:', hasattr(c,'lsmas'))"
# Must show: lsmas: True
```

### Step 3: Install Rust

av1an is written in Rust and needs to be compiled.

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
```

### Step 4: Build SVT-AV1-HDR

```bash
cd /tmp
git clone --depth 1 https://github.com/juliobbv-p/svt-av1-hdr.git
cd svt-av1-hdr
mkdir -p Build/linux && cd Build/linux
cmake ../.. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/.local
make -j$(nproc)
make install
cd /tmp && rm -rf svt-av1-hdr
```

### Step 5: Install av1an

```bash
cargo install --git https://github.com/master-of-zen/Av1an.git av1an
```

### Step 6: Download FFmpeg with SVT-AV1-HDR

```bash
mkdir -p $HOME/.local/bin
curl -L "https://github.com/QuickFatHedgehog/FFmpeg-Builds-SVT-AV1-HDR/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz" -o /tmp/ffmpeg.tar.xz
tar -xf /tmp/ffmpeg.tar.xz --strip-components=1 -C $HOME/.local
rm /tmp/ffmpeg.tar.xz
```

---

## Environment Configuration

### Required Environment Variables

Add these to your `~/.bashrc` (or `~/.zshrc`):

```bash
# SVT-AV1-HDR + av1an environment
export LD_LIBRARY_PATH="$HOME/.local/lib64:$LD_LIBRARY_PATH"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export VAPOURSYNTH_PLUGIN_PATH="$HOME/.local/lib/vapoursynth:/usr/lib64/vapoursynth"
```

### Why Each Variable Matters

| Variable | Purpose |
|----------|---------|
| `LD_LIBRARY_PATH` | Tells the system where to find `libSvtAv1Enc.so.3` |
| `PATH` | Ensures your custom binaries are found first |
| `VAPOURSYNTH_PLUGIN_PATH` | Tells VapourSynth where to find plugins (lsmas, ffms2) |

### Applying Changes

```bash
# Option 1: Restart shell
exit
toolbox enter encoding

# Option 2: Source the file
source ~/.bashrc
```

---

## Usage

### Basic Encoding

```bash
./av1an-svt-hdr-encode.sh input.mkv output.mkv
```

### Custom Settings

```bash
CRF=28 PRESET=6 WORKERS=8 ./av1an-svt-hdr-encode.sh input.mkv output.mkv
```

### Available Options

| Variable | Default | Range | Description |
|----------|---------|-------|-------------|
| `CRF` | 28 | 0-63 | Quality level (lower = better quality, larger file) |
| `PRESET` | 6 | 0-13 | Speed preset (0 = slowest/best, 13 = fastest) |
| `WORKERS` | 4 | 1-N | Number of parallel encoding workers |

### Recommended Settings by Content Type

**HDR Movies (Film Grain)**
```bash
CRF=30 PRESET=4 WORKERS=8 ./av1an-svt-hdr-encode.sh movie.mkv movie-av1.mkv
```

**HDR Movies (Clean/Digital)**
```bash
CRF=28 PRESET=6 WORKERS=8 ./av1an-svt-hdr-encode.sh movie.mkv movie-av1.mkv
```

**4K HDR Content**
```bash
CRF=32 PRESET=6 WORKERS=4 ./av1an-svt-hdr-encode.sh 4k-content.mkv output.mkv
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. `libSvtAv1Enc.so.3: cannot open shared object file`

**Cause**: `LD_LIBRARY_PATH` not set

**Fix**:
```bash
export LD_LIBRARY_PATH="$HOME/.local/lib64:$LD_LIBRARY_PATH"
```

Add to `~/.bashrc` to make permanent.

---

#### 2. av1an hangs with 0% CPU / empty output files

**Cause**: Missing VapourSynth source plugin (lsmas or ffms2)

**Verify**:
```bash
python3 -c "import vapoursynth as vs; c=vs.core; print('lsmas:', hasattr(c,'lsmas'), 'ffms2:', hasattr(c,'ffms2'))"
```

If both are `False`, fix with:
```bash
sudo dnf copr enable -y flawlessmedia/av-rpm
sudo dnf install -y vapoursynth-plugin-l-smash
```

---

#### 3. `Failed to get VSScript API`

**Cause**: VapourSynth Python bindings not installed

**Fix**:
```bash
sudo dnf install -y python3-vapoursynth
```

---

#### 4. `av1an: command not found`

**Cause**: Cargo bin not in PATH

**Fix**:
```bash
export PATH="$HOME/.cargo/bin:$PATH"
```

---

#### 5. Encoded chunks are 0 bytes

**Cause**: Encoder failing silently (usually library not found)

**Verify encoder works**:
```bash
SvtAv1EncApp --version
```

If it shows "cannot open shared object file", see issue #1 above.

---

#### 6. `pip3: command not found`

**Fix**:
```bash
sudo dnf install -y python3-pip
```

---

#### 7. Scene detection takes forever

**This is normal** for large 4K files. av1an needs to scan the entire file to find scene cuts. For a 50GB+ 4K remux, this can take 5-15 minutes.

To monitor progress:
```bash
# In another terminal, watch the temp directory
watch -n 2 'ls -la /tmp/av1an-*/ 2>/dev/null | head -20'
```

---

### Verification Commands

Run these to confirm everything is working:

```bash
# 1. Check SVT-AV1-HDR encoder
SvtAv1EncApp --version
# Expected: SVT-AV1-HDR 84b3348 (release)

# 2. Check library is loadable
ldd $(which SvtAv1EncApp) | grep -i svt
# Expected: libSvtAv1Enc.so.3 => /home/user/.local/lib64/libSvtAv1Enc.so.3

# 3. Check av1an
av1an --version
# Expected: av1an 0.5.2 or similar

# 4. Check VapourSynth plugins
python3 -c "
import vapoursynth as vs
core = vs.core
print('Plugins:', [p.namespace for p in core.plugins()])
print('lsmas:', hasattr(core, 'lsmas'))
print('ffms2:', hasattr(core, 'ffms2'))
"
# Expected: lsmas: True (ffms2 can be True or False)

# 5. Check FFmpeg
ffmpeg -version 2>&1 | head -1
# Expected: ffmpeg version ...
```

---

## Technical Details

### How av1an Works

1. **Scene Detection**: Scans video to find scene changes
2. **Chunk Creation**: Splits video at scene boundaries
3. **Parallel Encoding**: Spawns multiple encoder processes (one per worker)
4. **Concatenation**: Merges encoded chunks with mkvmerge
5. **Audio Handling**: Copies or re-encodes audio track

### SVT-AV1-HDR Specific Parameters

The encode script uses these HDR-optimized settings:

```
--tune 0                    # Psychovisual optimization (VQ mode)
--variance-boost-curve 3    # HDR contrast preservation curve
```

### Color Metadata Preservation

HDR color metadata is preserved via FFmpeg parameters:

```
-color_primaries bt2020     # BT.2020 color gamut
-color_trc smpte2084        # PQ (Perceptual Quantizer) transfer
-colorspace bt2020nc        # BT.2020 non-constant luminance
```

### File Locations

| Item | Location |
|------|----------|
| SVT-AV1-HDR binary | `~/.local/bin/SvtAv1EncApp` |
| SVT-AV1-HDR library | `~/.local/lib64/libSvtAv1Enc.so.3` |
| av1an binary | `~/.cargo/bin/av1an` |
| FFmpeg binary | `~/.local/bin/ffmpeg` |
| VapourSynth plugins (system) | `/usr/lib64/vapoursynth/` |
| VapourSynth plugins (user) | `~/.local/lib/vapoursynth/` |
| Temp files during encode | `/tmp/av1an-XXXXXX/` |

---

## Appendix: Full Dependency List

### DNF Packages

```bash
# Build tools
gcc gcc-c++ make cmake nasm git curl

# Python
python3-pip

# VapourSynth
vapoursynth-libs
python3-vapoursynth
vapoursynth-tools

# Video tools
ffms2
mkvtoolnix

# VapourSynth plugin (from COPR)
vapoursynth-plugin-l-smash
```

### COPR Repositories

```bash
flawlessmedia/av-rpm    # VapourSynth plugins
```

### Cargo Packages

```bash
av1an    # from git: https://github.com/master-of-zen/Av1an.git
```

### Built from Source

```bash
SVT-AV1-HDR    # from: https://github.com/juliobbv-p/svt-av1-hdr
```

### Pre-built Binaries

```bash
FFmpeg         # from: https://github.com/QuickFatHedgehog/FFmpeg-Builds-SVT-AV1-HDR
```
