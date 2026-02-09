# SVT-AV1-HDR + av1an Troubleshooting Guide

This document chronicles all issues encountered while setting up SVT-AV1-HDR with av1an on Fedora/Aurora Linux using a Distrobox/Toolbox container.

---

## Table of Contents

1. [Environment Issues](#environment-issues)
2. [VapourSynth Issues](#vapoursynth-issues)
3. [av1an Configuration Issues](#av1an-configuration-issues)
4. [Encoder Issues](#encoder-issues)
5. [Resource/Performance Issues](#resourceperformance-issues)
6. [Working Solutions](#working-solutions)

---

## Environment Issues

### Issue: Commands fail on host vs toolbox

**Symptom:**
```
thread 'main' panicked at ... Failed to get VSScript API
```

**Cause:** Running av1an on the host system (Aurora/Fedora Atomic) instead of inside the Distrobox where dependencies are installed.

**Solution:** Always enter the toolbox first:
```bash
toolbox enter encoding
```

The prompt changes from `📦[dark-moon@cursor` to `⬢ [dark-moon@toolbx` when inside.

---

### Issue: `libSvtAv1Enc.so.3: cannot open shared object file`

**Symptom:**
```
SvtAv1EncApp: error while loading shared libraries: libSvtAv1Enc.so.3: cannot open shared object file
```

**Cause:** The SVT-AV1-HDR library was installed to `~/.local/lib64` but that path isn't in the library search path.

**Solution:** Set `LD_LIBRARY_PATH` before running any encoder:
```bash
export LD_LIBRARY_PATH="$HOME/.local/lib64:$LD_LIBRARY_PATH"
```

Add to `~/.bashrc` for persistence:
```bash
echo 'export LD_LIBRARY_PATH="$HOME/.local/lib64:$LD_LIBRARY_PATH"' >> ~/.bashrc
```

---

### Issue: Cargo env file not found on toolbox entry

**Symptom:**
```
bash: /tmp/cursor-sandbox-cache/.../cargo/env: No such file or directory
```

**Cause:** Cursor IDE added a temp path to `.bashrc` that got cleaned up.

**Solution:** Harmless warning, but can be fixed:
```bash
sed -i '/cursor-sandbox-cache/d' ~/.bashrc
```

---

## VapourSynth Issues

### Issue: `libvapoursynth-script.so.0: cannot open shared object file`

**Symptom:**
```
av1an: error while loading shared libraries: libvapoursynth-script.so.0: cannot open shared object file
```

**Cause:** VapourSynth libraries not installed.

**Solution:**
```bash
sudo dnf install -y vapoursynth-libs python3-vapoursynth
```

---

### Issue: `Failed to get VSScript API`

**Symptom:**
```
thread 'main' panicked at .../vapoursynth-0.5.2/src/vsscript/mod.rs:83:28:
Failed to get VSScript API
```

**Cause:** `python3-vapoursynth` package missing (provides the VSScript bindings).

**Solution:**
```bash
sudo dnf install -y python3-vapoursynth vapoursynth-tools
```

---

### Issue: Missing source plugins (ffms2/lsmas)

**Symptom:**
```python
>>> print([p.namespace for p in core.plugins()])
['resize', 'std', 'text']  # No ffms2 or lsmas!
```

av1an hangs or fails because it can't read the video file.

**Cause:** VapourSynth source plugins aren't installed. The `ffms2` dnf package provides the library but NOT the VapourSynth plugin.

**Solution:**
```bash
# Enable COPR with VapourSynth plugins
sudo dnf copr enable -y flawlessmedia/av-rpm

# Install L-SMASH plugin (preferred for HDR)
sudo dnf install -y vapoursynth-plugin-l-smash

# Set plugin path
export VAPOURSYNTH_PLUGIN_PATH="$HOME/.local/lib/vapoursynth:/usr/lib64/vapoursynth"
```

Verify:
```bash
python3 -c "
import vapoursynth as vs
core = vs.core
print('Plugins:', [p.namespace for p in core.plugins()])
print('Has lsmas:', hasattr(core, 'lsmas'))
"
```

Expected output includes `lsmas` in the plugins list.

---

### Issue: `vsrepo.py: command not found` / `No module named vsrepo`

**Symptom:**
```
bash: vsrepo.py: command not found
ERROR: No matching distribution found for vsrepo
```

**Cause:** `vsrepo` is NOT a pip package. It's a script bundled with `vapoursynth-tools`.

**Solution:**
```bash
sudo dnf install -y vapoursynth-tools
# The script location varies; on Fedora it may not be in PATH
# Use the COPR method above instead for installing plugins
```

---

### Issue: av1an hangs on VapourSynth initialization

**Symptom:** av1an starts but produces no output, no temp directory created, 0% CPU usage.

```bash
$ ps aux | grep av1an
av1an -i ... # Process exists but does nothing

$ ls /tmp/av1an-*
# Empty or no directory
```

**Cause:** av1an links against VapourSynth and initializes it even when using `--chunk-method segment`. The VSScript API hangs during initialization in certain environments.

**Workarounds attempted:**
- `--chunk-method segment` - Still hangs
- `--split-method none` - Still hangs  
- `--chunk-method hybrid` - Still hangs

**SOLUTION:**

The root cause was that **VapourSynth had no source plugins** to read video files. The `ffms2` dnf package provides only the C library, NOT the VapourSynth plugin. COPR repos didn't have the VS plugin for Fedora 42 either.

The fix:

1. **Compile FFMS2 from source** and symlink to VapourSynth plugin directory:
   ```bash
   git clone --branch 5.0 --depth 1 https://github.com/FFMS/ffms2.git
   cd ffms2 && ./autogen.sh
   ./configure --enable-shared --prefix=/usr/local
   make -j$(nproc) && sudo make install
   VS_PLUGIN_PATH=$(pkg-config --variable=libdir vapoursynth)/vapoursynth
   sudo ln -sf /usr/local/lib/libffms2.so "$VS_PLUGIN_PATH/libffms2.so"
   sudo ldconfig
   ```

2. **Install av1an from the `rust-av` fork** (not `master-of-zen`):
   ```bash
   cargo install --git https://github.com/rust-av/Av1an.git --bin av1an
   ```

3. **Use `--chunk-method ffms2`** with `--split-method av-scenechange`:
   ```bash
   av1an -i input.mkv -o output.mkv -e svt-av1 \
       --chunk-method ffms2 --split-method av-scenechange \
       --pix-format yuv420p10le ...
   ```

4. **Verify the fix:**
   ```bash
   python3 -c "import vapoursynth as vs; print('ffms2:', hasattr(vs.core, 'ffms2'))"
   # Must show: ffms2: True
   ```

Or run the automated setup: `./setup-av1an-svt-hdr.sh`

**Based on:** [Auto-Boost-Av1an-Linux](https://github.com/abdulrahmanx9/Auto-Boost-Av1an-Linux)

---

## av1an Configuration Issues

### Issue: `a value is required for '--video-params <VIDEO_PARAMS>'`

**Symptom:**
```
error: a value is required for '--video-params <VIDEO_PARAMS>' but none was supplied
```

**Cause:** Improper quoting of the video params string in shell.

**Solution:** Quote the entire params string properly:
```bash
# Wrong
-v --preset 6 --crf 28

# Correct
-v "--preset 6 --crf 28"
```

---

### Issue: L-SMASH index race condition

**Symptom:**
```
Svt[error]: Instance 1: Source Width must be at least 4
Svt[error]: Instance 1: Source Height must be at least 4
source pipe stderr: Creating lwi index file 31%
ffmpeg pipe stderr: Error opening input: Invalid data found when processing input
```

**Cause:** L-SMASH plugin creates an index file (`.lwi`) on first run. With multiple workers, they all try to read the incomplete index simultaneously, causing FFmpeg to receive garbage data.

**Solution options:**
1. Pre-build the index before encoding (run a quick scene detection pass first)
2. Use `--chunk-method segment` instead of `--chunk-method lsmash`
3. Use `-w 1` (single worker) for first run to build index

---

### Issue: Invalid encoder parameters

**Symptom:**
```
Unprocessed tokens: --enable-hdr 
Unprocessed arguments: 1
Error in configuration, could not begin encoding!
```

**Cause:** The SVT-AV1-HDR fork doesn't have `--enable-hdr` flag - it auto-detects HDR content.

**Invalid parameters for SVT-AV1-HDR:**
- `--enable-hdr` - Doesn't exist (auto-detected)
- `--input-depth` - Handled by av1an's `--pix-format`

**Correct parameters:**
```bash
-v "--preset 6 --crf 28 --tune 0 --color-primaries 9 --transfer-characteristics 16 --matrix-coefficients 9 --mastering-display G(...)B(...)R(...)WP(...)L(...) --content-light MaxCLL,MaxFALL --variance-boost-curve 3"
```

---

## Encoder Issues

### Issue: FFmpeg doesn't find libsvtav1

**Symptom:**
```
Unknown encoder 'libsvtav1'
```

**Cause:** System FFmpeg doesn't have SVT-AV1 support compiled in.

**Solution:** Use a pre-built FFmpeg with libsvtav1:
```bash
# Download static build
curl -L "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz" | \
    tar xJf - --strip-components=1 -C ~/.local/bin/ --wildcards '*/ffmpeg' '*/ffprobe'
```

Verify:
```bash
ffmpeg -encoders 2>/dev/null | grep svtav1
# Should show: V....D libsvtav1
```

---

### Issue: NAL unit 63 spam in logs

**Symptom:**
```
[hevc @ 0x...] Skipping NAL unit 63
    Last message repeated 10 times
```

**Cause:** Dolby Vision metadata in the source file. Harmless warning.

**Solution:** Suppress with log level:
```bash
ffmpeg -loglevel warning -stats ...
```

---

## Resource/Performance Issues

### Issue: System freezes / RAM exhaustion

**Symptom:** System becomes unresponsive when av1an starts encoding. RAM usage spikes to 100%.

**Cause:** SVT-AV1 at preset 6 uses ~300 frame lookahead. With 4K 10-bit content:
- Each frame ≈ 50MB uncompressed
- 6 workers × 300 frames × 50MB = ~90GB RAM needed

**Solution:** Reduce workers and limit encoder threads:
```bash
av1an ... \
    -w 2 \                    # Only 2 parallel encodes
    -v "--lp 4 ..." \         # Limit encoder thread pool
    ...
```

For 30GB RAM system with 4K HDR:
- Maximum safe workers: 2
- Add `--lp 4` to limit per-instance threads

---

## Working Solutions

### Option 1: Direct FFmpeg (Recommended - Always Works)

```bash
export LD_LIBRARY_PATH="$HOME/.local/lib64:$LD_LIBRARY_PATH" && \
ffmpeg -loglevel warning -stats \
    -i "input.mkv" \
    -map 0:v:0 -map 0:a -map 0:s? \
    -c:v libsvtav1 -crf 28 -preset 6 \
    -svtav1-params "tune=0:enable-variance-boost=1:variance-boost-strength=2:variance-octile=5:variance-boost-curve=3:sharpness=1:qp-scale-compress-strength=1" \
    -pix_fmt yuv420p10le \
    -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc \
    -c:a copy -c:s copy \
    "output.mkv"
```

**Pros:** Reliable, no VapourSynth issues
**Cons:** Single encode pipeline (slower than parallel chunking)

---

### Option 2: av1an with Parallel Chunking (Proven Working)

Requires FFMS2 compiled from source (see setup script). Multiple successful encodes confirmed.

```bash
export LD_LIBRARY_PATH="$HOME/.local/lib64:/usr/local/lib:$LD_LIBRARY_PATH" && \
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH" && \
export VAPOURSYNTH_PLUGIN_PATH="/usr/local/lib/vapoursynth:$HOME/.local/lib/vapoursynth" && \
av1an -i "input.mkv" \
    -o "output.mkv" \
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

**Key flags:**
- `--chunk-method ffms2` - Uses compiled FFMS2 plugin (NOT lsmash, NOT segment)
- `--split-method av-scenechange` - av1an's built-in Rust scene detector
- `-x 240` - Extra split every 240 frames (~10 sec at 24fps)
- `-w 2` - 2 workers for 4K HDR (use 4 for 1080p)
- `--lp 4` - Limit encoder thread pool per instance
- `--concat mkvmerge` - Reliable concatenation

---

## Quick Diagnostic Commands

```bash
# Check if inside toolbox
echo $HOSTNAME  # Should be "toolbx"

# Verify SVT-AV1-HDR
SvtAv1EncApp --version

# Verify VapourSynth
python3 -c "import vapoursynth as vs; print(vs.__version__)"

# Check VapourSynth plugins
python3 -c "import vapoursynth as vs; print([p.namespace for p in vs.core.plugins()])"

# Check FFmpeg encoders
ffmpeg -encoders 2>/dev/null | grep -E "(svtav1|libsvtav1)"

# Monitor RAM during encode
watch -n 1 free -h

# Check av1an processes
ps aux | grep -E "(av1an|SvtAv1|ffmpeg)"

# Check av1an temp directory
ls -la /tmp/av1an-*/
```

---

## Environment Variables Checklist

```bash
# Required for SVT-AV1-HDR library
export LD_LIBRARY_PATH="$HOME/.local/lib64:$LD_LIBRARY_PATH"

# Required for custom binaries
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# Required for VapourSynth plugins
export VAPOURSYNTH_PLUGIN_PATH="$HOME/.local/lib/vapoursynth:/usr/lib64/vapoursynth"
```

Add all three to `~/.bashrc` for persistence inside the toolbox.

---

## Summary

| Issue | Root Cause | Solution |
|-------|-----------|----------|
| Missing .so files | Library path not set | Set `LD_LIBRARY_PATH` |
| VSScript API fail | Missing python3-vapoursynth | `dnf install python3-vapoursynth` |
| No source plugins | Missing VS plugins | Install via COPR |
| av1an hangs | Missing FFMS2 VS plugin | Compile FFMS2, use `--chunk-method ffms2` |
| Encoder rejects params | Wrong flags for HDR fork | Remove `--enable-hdr` |
| RAM exhaustion | Too many workers + 4K | Use `-w 2 --lp 4` |
| Index race condition | L-SMASH concurrent access | Use `--chunk-method segment` |

**Bottom line:** With FFMS2 compiled from source and symlinked to VapourSynth, av1an works reliably with `--chunk-method ffms2`. Multiple successful encodes confirmed (Feb 4-6, 2026 logs). If av1an still won't work, use FFmpeg directly as a fallback - it's slower but 100% reliable.
