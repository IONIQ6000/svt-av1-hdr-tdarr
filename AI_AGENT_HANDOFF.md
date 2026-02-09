# AI Agent Handoff: SVT-AV1-HDR + av1an on Fedora/Aurora

## CRITICAL CONTEXT FOR FUTURE AI AGENTS

This document provides the **complete, battle-tested** knowledge required to set up and operate SVT-AV1-HDR with av1an for parallel HDR AV1 encoding on Fedora-based immutable systems (Aurora, Silverblue, Kinoite). Every detail here was learned through extensive real-world troubleshooting. **Do not deviate from this guide without good reason.**

---

## Table of Contents

1. [System Architecture](#1-system-architecture)
2. [What Actually Works (Proven Configuration)](#2-what-actually-works-proven-configuration)
3. [Complete Setup Procedure](#3-complete-setup-procedure)
4. [The Working av1an Command](#4-the-working-av1an-command)
5. [Direct FFmpeg Fallback](#5-direct-ffmpeg-fallback)
6. [Every Issue We Hit (Chronological)](#6-every-issue-we-hit-chronological)
7. [Parameter Reference](#7-parameter-reference)
8. [HDR Metadata Extraction](#8-hdr-metadata-extraction)
9. [Resource Limits](#9-resource-limits)
10. [Verification Procedures](#10-verification-procedures)
11. [Key Files in This Repository](#11-key-files-in-this-repository)

---

## 1. System Architecture

```
Host: Aurora Linux (Fedora Atomic/immutable)
  |
  +-- Toolbox/Distrobox container named "encoding"
       |-- Fedora 42 base (mutable, has dnf)
       |-- SVT-AV1-HDR (compiled from source -> ~/.local/)
       |-- av1an (installed via cargo from rust-av fork)
       |-- VapourSynth R70 (system packages)
       |-- FFMS2 (compiled from source, symlinked to VS plugin dir)
       |-- FFmpeg (pre-built static binary with libsvtav1)
       |-- mkvtoolnix (system package)
```

**CRITICAL**: All encoding MUST happen inside the toolbox. The host system does NOT have the required libraries. The toolbox prompt looks like `[dark-moon@toolbx`.

Enter with:
```bash
toolbox enter encoding
```

---

## 2. What Actually Works (Proven Configuration)

### Confirmed successful encodes (from logs dated Feb 4-6, 2026):

The following configuration completed **multiple full encodes** successfully:

```
av1an version: installed from https://github.com/rust-av/Av1an.git
Chunk method:  FFMS2 (compiled from source, linked as VapourSynth plugin)
Split method:  av-scenechange (av1an's built-in Rust scene detector)
Workers:       4 (for 1080p content)
Encoder:       svt-av1 (SVT-AV1-HDR fork)
Concatenation: mkvmerge
```

**Exact working video_params from successful encodes:**
```
--crf 28 --preset 6 --tune 0 --variance-boost-curve 3 --lp 4
```

**Exact working ffmpeg_filter_args:**
```
-color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc
```

**Exact working audio_params:**
```
-c:a copy
```

**Output pix format:** `yuv420p10le` (10-bit, CRITICAL for HDR)

### What the setup script does (and MUST do):

1. Installs VapourSynth from **system packages** (dnf)
2. Compiles FFMS2 **from source** (tag 5.0) and **symlinks** it to VapourSynth's plugin directory
3. Installs av1an from the **rust-av fork** (NOT master-of-zen)
4. Compiles SVT-AV1-HDR to `~/.local/`
5. Downloads a pre-built FFmpeg with libsvtav1 support

---

## 3. Complete Setup Procedure

### Step 1: Create the toolbox
```bash
toolbox create encoding
toolbox enter encoding
```

### Step 2: Install system dependencies
```bash
sudo dnf install -y \
    gcc gcc-c++ make cmake nasm git curl \
    autoconf automake libtool pkg-config \
    python3-devel python3-pip \
    zlib-devel \
    mkvtoolnix \
    vapoursynth \
    vapoursynth-libs \
    vapoursynth-devel \
    vapoursynth-tools \
    python3-vapoursynth
```

**Why each package matters:**
- `vapoursynth-libs`: provides `libvapoursynth-script.so.0` (av1an links against this)
- `python3-vapoursynth`: provides VSScript API (av1an panics without this)
- `vapoursynth-devel`: provides `pkg-config` files for compiling FFMS2 against VS
- `vapoursynth-tools`: provides `vspipe` binary

### Step 3: Compile FFMS2 from source

**WHY**: The `ffms2` dnf package provides the library but NOT the VapourSynth plugin. System VapourSynth plugin packages for FFMS2 are NOT available on Fedora 42. The COPR repos don't have them either. The ONLY reliable method is compiling from source and symlinking.

```bash
# Get VapourSynth plugin directory
VS_PLUGIN_PATH=$(pkg-config --variable=libdir vapoursynth)/vapoursynth
sudo mkdir -p "$VS_PLUGIN_PATH"

# Install FFMS2 build dependencies
sudo dnf install -y ffmpeg-devel ffmpeg-libs

# Build FFMS2
mkdir -p /tmp/build_tmp && cd /tmp/build_tmp
rm -rf ffms2
git clone --branch 5.0 --depth 1 https://github.com/FFMS/ffms2.git
cd ffms2
./autogen.sh
./configure --enable-shared --prefix=/usr/local
make -j$(nproc)
sudo make install

# CRITICAL: Symlink to VapourSynth plugin directory
sudo ln -sf /usr/local/lib/libffms2.so "$VS_PLUGIN_PATH/libffms2.so"
sudo ldconfig
```

**VERIFICATION** (must show `ffms2: True`):
```bash
python3 -c "
import vapoursynth as vs
core = vs.core
print('has ffms2:', hasattr(core, 'ffms2'))
"
```

### Step 4: Install Rust and av1an

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# IMPORTANT: Use the rust-av fork, NOT master-of-zen
# Set paths for cargo to find VapourSynth headers
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$(pkg-config --variable=pc_path pkg-config):$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
export LIBRARY_PATH="/usr/local/lib:$LIBRARY_PATH"

cargo install --git https://github.com/rust-av/Av1an.git --bin av1an
```

### Step 5: Compile SVT-AV1-HDR

```bash
cd /tmp/build_tmp
rm -rf svt-av1-hdr
git clone --depth 1 https://github.com/juliobbv-p/svt-av1-hdr.git
cd svt-av1-hdr
mkdir -p Build/linux && cd Build/linux
cmake ../.. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/.local
make -j$(nproc)
make install
```

### Step 6: Download FFmpeg with libsvtav1

```bash
mkdir -p $HOME/.local/bin
curl -L "https://github.com/QuickFatHedgehog/FFmpeg-Builds-SVT-AV1-HDR/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz" -o /tmp/ffmpeg.tar.xz
tar -xf /tmp/ffmpeg.tar.xz --strip-components=1 -C $HOME/.local
rm /tmp/ffmpeg.tar.xz
```

### Step 7: Configure environment variables

Add to `~/.bashrc`:
```bash
# SVT-AV1-HDR + av1an environment
export LD_LIBRARY_PATH="$HOME/.local/lib64:/usr/local/lib:$LD_LIBRARY_PATH"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export VAPOURSYNTH_PLUGIN_PATH="/usr/local/lib/vapoursynth:$HOME/.local/lib/vapoursynth"
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
```

**Then restart shell:**
```bash
source ~/.bashrc
```

---

## 4. The Working av1an Command

### For HDR content (with mastering display metadata):

```bash
av1an \
    -i "INPUT.mkv" \
    -o "OUTPUT.mkv" \
    -e svt-av1 \
    -w 2 \
    --chunk-method ffms2 \
    --split-method av-scenechange \
    -x 240 \
    --pix-format yuv420p10le \
    --concat mkvmerge \
    -v "--crf 28 --preset 6 --tune 0 --lp 4 --color-primaries 9 --transfer-characteristics 16 --matrix-coefficients 9 --mastering-display G(0.1700,0.7970)B(0.1310,0.0460)R(0.7080,0.2920)WP(0.3127,0.3290)L(1000.0,0.0001) --content-light 949,438 --variance-boost-curve 3" \
    -f "-color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc" \
    -a "-c:a copy" \
    --verbose
```

### For SDR content (no mastering display needed):

```bash
av1an \
    -i "INPUT.mkv" \
    -o "OUTPUT.mkv" \
    -e svt-av1 \
    -w 4 \
    --chunk-method ffms2 \
    --split-method av-scenechange \
    -x 240 \
    --pix-format yuv420p10le \
    --concat mkvmerge \
    -v "--crf 28 --preset 6 --tune 0 --variance-boost-curve 3 --lp 4" \
    -f "-color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc" \
    -a "-c:a copy" \
    --verbose
```

### CRITICAL: What each flag does and why it's there

| Flag | Value | Why |
|------|-------|-----|
| `-e svt-av1` | Encoder selection | Tells av1an to use SvtAv1EncApp |
| `-w 2` | Workers for 4K HDR | 4K HDR uses ~15GB/worker. 2 workers = ~30GB. More = OOM freeze |
| `-w 4` | Workers for 1080p | 1080p uses less RAM, 4 workers is safe |
| `--chunk-method ffms2` | **CRITICAL** | Uses our compiled FFMS2. Do NOT use `lsmash` (index race condition). Do NOT use `segment` (can hang on VapourSynth init) |
| `--split-method av-scenechange` | Scene detection | Uses av1an's built-in Rust scene detector. Works reliably |
| `-x 240` | Extra split length | Splits every 240 frames (~10s at 24fps) as fallback |
| `--pix-format yuv420p10le` | **CRITICAL for HDR** | Without this, pipe sends 8-bit data and SVT-AV1-HDR crashes |
| `--concat mkvmerge` | Concatenation method | Reliable MKV stitching |
| `--lp 4` | Encoder thread pool | Limits SVT-AV1 internal threads per worker instance |
| `--verbose` | Logging | Shows chunk progress and any errors |

### Parameters that DO NOT EXIST in SVT-AV1-HDR (will cause immediate failure):

- `--enable-hdr` - Does NOT exist. HDR is auto-detected
- `--input-depth` - Handled by av1an's `--pix-format`

---

## 5. Direct FFmpeg Fallback

If av1an refuses to cooperate, this always works:

```bash
export LD_LIBRARY_PATH="$HOME/.local/lib64:$LD_LIBRARY_PATH" && \
ffmpeg -loglevel warning -stats \
    -i "INPUT.mkv" \
    -map 0:v:0 -map 0:a -map 0:s? \
    -c:v libsvtav1 -crf 28 -preset 6 \
    -svtav1-params "tune=0:enable-variance-boost=1:variance-boost-strength=2:variance-octile=5:variance-boost-curve=3:sharpness=1:qp-scale-compress-strength=1" \
    -pix_fmt yuv420p10le \
    -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc \
    -c:a copy -c:s copy \
    "OUTPUT.mkv"
```

**Note:** `-loglevel warning -stats` suppresses the harmless `Skipping NAL unit 63` Dolby Vision spam while keeping the progress counter.

**Performance:** ~9-10 fps for 4K on Ryzen 9 7900X3D. Single pipeline, no parallel chunking. A 2h14m movie takes ~6 hours.

---

## 6. Every Issue We Hit (Chronological)

### Issue 1: `libvapoursynth-script.so.0: cannot open shared object file`
- **When:** First run of av1an
- **Cause:** `vapoursynth-libs` package not installed
- **Fix:** `sudo dnf install -y vapoursynth-libs python3-vapoursynth`

### Issue 2: `Failed to get VSScript API` (Rust panic)
- **When:** After installing vapoursynth-libs but missing python3-vapoursynth
- **Cause:** VSScript API requires Python bindings
- **Fix:** `sudo dnf install -y python3-vapoursynth`

### Issue 3: av1an hangs at 0% with no CPU activity
- **When:** VapourSynth loaded but no source plugins available
- **Cause:** VapourSynth had no way to read video files (no ffms2 or lsmas plugin)
- **Diagnosis:** `python3 -c "import vapoursynth as vs; print([p.namespace for p in vs.core.plugins()])"` showed only `['resize', 'std', 'text']` - no source plugin
- **Fix:** Compile FFMS2 from source and symlink (see Setup Step 3)

### Issue 4: `ffms2` dnf package doesn't provide VapourSynth plugin
- **When:** After `sudo dnf install -y ffms2`
- **Cause:** The ffms2 RPM provides the C library but NOT the VapourSynth plugin `.so`
- **Fix:** Must compile FFMS2 from source with VapourSynth support

### Issue 5: `vsrepo.py: command not found` / `No module named vsrepo`
- **When:** Trying to install VS plugins via vsrepo
- **Cause:** `vsrepo` is NOT a pip package. It's bundled with `vapoursynth-tools`
- **Fix:** Don't use vsrepo. Compile FFMS2 from source instead

### Issue 6: COPR VapourSynth plugins not available for Fedora 42
- **When:** `sudo dnf install -y vapoursynth-plugin-ffms2` from rpmfusion
- **Cause:** Neither rpmfusion nor scaronni/vapoursynth-plugins COPR had the package for fc42
- **Fix:** Compile FFMS2 from source (the only reliable method)

### Issue 7: L-SMASH installed from COPR but index race condition
- **When:** `vapoursynth-plugin-l-smash` installed from `flawlessmedia/av-rpm` COPR
- **Symptom:** `Creating lwi index file 31%` while workers try to read the incomplete index
- **Error:** `Svt[error]: Source Width must be at least 4` (encoder receives garbage data)
- **Fix:** Use `--chunk-method ffms2` instead of `--chunk-method lsmash`

### Issue 8: `libSvtAv1Enc.so.3: cannot open shared object file`
- **When:** Running SvtAv1EncApp after compilation
- **Cause:** Library installed to `~/.local/lib64/` which isn't in system library path
- **Fix:** `export LD_LIBRARY_PATH="$HOME/.local/lib64:$LD_LIBRARY_PATH"`

### Issue 9: `--video-params` empty value error
- **When:** Bad quoting in shell script
- **Symptom:** `error: a value is required for '--video-params <VIDEO_PARAMS>'`
- **Fix:** Use `VIDEO_PARAMS="--crf 28 ..."` variable and pass as `-v "$VIDEO_PARAMS"`

### Issue 10: `Unprocessed tokens: --enable-hdr`
- **When:** Using parameters from the integration guide document
- **Cause:** `--enable-hdr` does NOT exist in SVT-AV1-HDR. HDR is auto-detected from input
- **Fix:** Remove `--enable-hdr 1` and `--input-depth 10` from video params

### Issue 11: RAM exhaustion / system freeze
- **When:** Running with 6-8 workers on 4K HDR content
- **Cause:** Each SVT-AV1 instance at preset 6 buffers ~300 frames for lookahead. At 4K 10-bit: 6 workers x 300 frames x 50MB = ~90GB
- **Fix:** Reduce to `-w 2` and add `--lp 4` to limit internal thread pool

### Issue 12: `Skipping NAL unit 63` log spam
- **When:** FFmpeg decoding Dolby Vision content
- **Cause:** Harmless DV metadata NAL units
- **Fix:** `ffmpeg -loglevel warning -stats ...`

### Issue 13: Cargo env file not found on toolbox entry
- **When:** Entering toolbox after Cursor IDE added temp paths to .bashrc
- **Symptom:** `bash: /tmp/cursor-sandbox-cache/.../cargo/env: No such file or directory`
- **Fix:** `sed -i '/cursor-sandbox-cache/d' ~/.bashrc`

### Issue 14: av1an from master-of-zen hangs on VapourSynth init
- **When:** Running av1an compiled from `master-of-zen/Av1an.git`
- **Cause:** Older codebase with different VapourSynth initialization
- **Fix:** Install from `rust-av/Av1an.git` instead

---

## 7. Parameter Reference

### SVT-AV1-HDR Encoder Parameters (passed via `-v`)

| Parameter | Value | Description |
|-----------|-------|-------------|
| `--crf` | 0-63 | Quality (28 default, lower = better quality) |
| `--preset` | 0-13 | Speed (6 default, 0 = slowest/best) |
| `--tune` | 0 | VQ mode (psychovisual optimization) |
| `--variance-boost-curve` | 3 | HDR contrast preservation curve |
| `--lp` | 4 | Thread pool limit per encoder instance |
| `--color-primaries` | 9 | BT.2020 |
| `--transfer-characteristics` | 16 | PQ (SMPTE 2084) |
| `--matrix-coefficients` | 9 | BT.2020 non-constant luminance |
| `--mastering-display` | `G(x,y)B(x,y)R(x,y)WP(x,y)L(max,min)` | Mastering display metadata (normalized floats!) |
| `--content-light` | `MaxCLL,MaxFALL` | Content light level |

### INVALID Parameters (DO NOT USE):

| Parameter | Why Invalid |
|-----------|-------------|
| `--enable-hdr` | Does not exist. HDR auto-detected |
| `--input-depth` | Handled by av1an's `--pix-format` |

### av1an Parameters

| Parameter | Recommended | Description |
|-----------|-------------|-------------|
| `-w` | 2 (4K) / 4 (1080p) | Parallel workers |
| `--chunk-method` | `ffms2` | Use compiled FFMS2 plugin |
| `--split-method` | `av-scenechange` | Built-in scene detection |
| `-x` | 240 | Extra split length (frames) |
| `--pix-format` | `yuv420p10le` | 10-bit HDR pixel format |
| `--concat` | `mkvmerge` | Chunk concatenation method |

---

## 8. HDR Metadata Extraction

To get mastering display metadata for a new file:

```bash
ffprobe -hide_banner -select_streams v:0 -show_frames -read_intervals "%+#1" "input.mkv" 2>&1 | \
    grep -E "(red_|green_|blue_|white_|max_|min_)" | head -12
```

**Output example:**
```
red_x=35400/50000      -> 0.7080
red_y=14600/50000      -> 0.2920
green_x=8500/50000     -> 0.1700
green_y=39850/50000    -> 0.7970
blue_x=6550/50000      -> 0.1310
blue_y=2300/50000      -> 0.0460
white_point_x=15635/50000  -> 0.3127
white_point_y=16450/50000  -> 0.3290
min_luminance=1/10000  -> 0.0001
max_luminance=10000000/10000  -> 1000.0
max_content=949        -> MaxCLL
max_average=438        -> MaxFALL
```

**Convert to mastering display string:**
```
--mastering-display G(0.1700,0.7970)B(0.1310,0.0460)R(0.7080,0.2920)WP(0.3127,0.3290)L(1000.0,0.0001)
--content-light 949,438
```

**CRITICAL:** Values MUST be normalized floats (divide by 50000). SVT-AV1-HDR will crash with raw integers.

---

## 9. Resource Limits

### Memory Guide

| Content | Workers | Approx RAM | Notes |
|---------|---------|------------|-------|
| 4K HDR | 2 | ~15-20GB | Safe for 32GB system |
| 4K HDR | 4 | ~30-40GB | Needs 64GB system |
| 1080p | 4 | ~8-12GB | Safe for 32GB system |
| 1080p | 8 | ~16-24GB | Safe for 32GB system |

### Thread Pool (`--lp`)

- Default: uses all cores per instance
- Recommended: `--lp 4` to prevent core contention between workers
- Formula: `--lp` = total_cores / workers (approximate)

### Hardware tested on:
- CPU: AMD Ryzen 9 7900X3D (12 cores, 24 threads)
- RAM: 30GB
- Safe config: `-w 2 --lp 4` for 4K HDR

---

## 10. Verification Procedures

Run these commands in order. ALL must pass:

```bash
# 1. Confirm inside toolbox
echo $HOSTNAME
# Expected: toolbx

# 2. SVT-AV1-HDR encoder
SvtAv1EncApp --version 2>&1 | head -1
# Expected: SVT-AV1-HDR Encoder Lib ... "Cyclonus"

# 3. Library linkage
ldd $(which SvtAv1EncApp) | grep SvtAv1
# Expected: libSvtAv1Enc.so.3 => /home/.../.local/lib64/libSvtAv1Enc.so.3

# 4. av1an
av1an --version 2>&1 | head -1
# Expected: av1an 0.5.x

# 5. VapourSynth + FFMS2 plugin (MOST CRITICAL)
python3 -c "
import vapoursynth as vs
core = vs.core
plugins = [p.namespace for p in core.plugins()]
print('Plugins:', plugins)
print('ffms2:', hasattr(core, 'ffms2'))
"
# Expected: ffms2: True

# 6. FFmpeg with libsvtav1
ffmpeg -encoders 2>/dev/null | grep svtav1
# Expected: V....D libsvtav1

# 7. mkvtoolnix
which mkvmerge
# Expected: /usr/bin/mkvmerge
```

---

## 11. Key Files in This Repository

| File | Purpose |
|------|---------|
| `setup-av1an-svt-hdr.sh` | Automated setup script - installs everything |
| `av1an-svt-hdr-encode.sh` | av1an encoding script with pre-flight checks |
| `svt-hdr-encode.sh` | Direct FFmpeg encoding script (fallback) |
| `verify-av1an-setup.sh` | Verification script - checks all components |
| `TROUBLESHOOTING.md` | Detailed troubleshooting for every error |
| `SETUP.md` | Step-by-step manual setup guide |
| `QUICKREF.md` | Quick reference cheat sheet |
| `README.md` | Project overview + Tdarr Docker setup |
| `AI_AGENT_HANDOFF.md` | This file - complete knowledge for AI agents |

### Environment Variables (must be in ~/.bashrc inside toolbox)

```bash
export LD_LIBRARY_PATH="$HOME/.local/lib64:/usr/local/lib:$LD_LIBRARY_PATH"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export VAPOURSYNTH_PLUGIN_PATH="/usr/local/lib/vapoursynth:$HOME/.local/lib/vapoursynth"
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
```

### Binary Locations

| Binary | Path |
|--------|------|
| SvtAv1EncApp | `~/.local/bin/SvtAv1EncApp` |
| libSvtAv1Enc.so.3 | `~/.local/lib64/libSvtAv1Enc.so.3` |
| av1an | `~/.cargo/bin/av1an` |
| ffmpeg | `~/.local/bin/ffmpeg` |
| ffprobe | `~/.local/bin/ffprobe` |
| FFMS2 VS plugin | `/usr/local/lib/vapoursynth/libffms2.so` (symlink) |
| mkvmerge | `/usr/bin/mkvmerge` |

---

## Summary: The One-Line Answer

**Q: How do you encode HDR video with SVT-AV1-HDR + av1an on Aurora Linux?**

**A:** Enter the `encoding` toolbox, ensure environment variables are set, then run av1an with `--chunk-method ffms2`, `--split-method av-scenechange`, `--pix-format yuv420p10le`, video params `"--crf 28 --preset 6 --tune 0 --variance-boost-curve 3 --lp 4"` plus HDR metadata, with 2 workers for 4K or 4 workers for 1080p. Never use `--enable-hdr` (doesn't exist). Never use `--chunk-method lsmash` (index race condition). Always compile FFMS2 from source as the VapourSynth plugin.
