# Tdarr with SVT-AV1-HDR

Custom Tdarr setup with the SVT-AV1-HDR encoder for psychovisually optimal HDR and SDR AV1 encoding.

## About SVT-AV1-HDR

[SVT-AV1-HDR](https://github.com/juliobbv-p/svt-av1-hdr) is a fork of SVT-AV1 with perceptual enhancements:

- **PQ-optimized Variance Boost**: Custom curve for HDR video with Perceptual Quantizer (PQ) transfer
- **Film Grain Tune (tune 4)**: Optimized for film grain retention and temporal consistency
- **56% smaller files**: Comparable quality at 56.6% the size of standard SVT-AV1 for HDR content

---

## Standalone av1an Encoding (Recommended for Manual Encodes)

For encoding outside of Tdarr, use av1an with SVT-AV1-HDR for parallel chunk encoding.

### Quick Start

```bash
# 1. Create and enter a toolbox/distrobox
toolbox create encoding
toolbox enter encoding

# 2. Run the setup script (installs everything)
./setup-av1an-svt-hdr.sh

# 3. Restart your shell (IMPORTANT!)
source ~/.bashrc

# 4. Encode!
./av1an-svt-hdr-encode.sh input.mkv output.mkv

# With custom settings:
CRF=28 PRESET=6 WORKERS=8 ./av1an-svt-hdr-encode.sh input.mkv output.mkv
```

### What Gets Installed

The setup script installs:

| Component | Purpose |
|-----------|---------|
| **SVT-AV1-HDR** | Psychovisually optimized encoder |
| **av1an** | Parallel chunked encoding framework |
| **VapourSynth + L-SMASH** | Video source plugin (required by av1an) |
| **FFmpeg** | Pre-built with SVT-AV1-HDR support |
| **mkvtoolnix** | Chunk concatenation |

### Environment Variables (CRITICAL)

These **must** be set for SVT-AV1-HDR to work:

```bash
export LD_LIBRARY_PATH="$HOME/.local/lib64:$LD_LIBRARY_PATH"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export VAPOURSYNTH_PLUGIN_PATH="$HOME/.local/lib/vapoursynth:/usr/lib64/vapoursynth"
```

The setup script adds these to `~/.bashrc` automatically, but you need to restart your shell or `source ~/.bashrc`.

### Troubleshooting

| Problem | Solution |
|---------|----------|
| `libSvtAv1Enc.so.3: cannot open shared object file` | Set `LD_LIBRARY_PATH` (see above) |
| av1an hangs with 0% CPU | Missing VapourSynth source plugin |
| `Failed to get VSScript API` | Install `python3-vapoursynth` |
| Encoded chunks are 0 bytes | SVT-AV1-HDR library not found |

**Verify your setup:**

```bash
# Check encoder works
SvtAv1EncApp --version

# Check VapourSynth has source plugins
python3 -c "import vapoursynth as vs; c=vs.core; print('lsmas:', hasattr(c,'lsmas'), 'ffms2:', hasattr(c,'ffms2'))"

# Should output: lsmas: True ffms2: False (or similar)
```

### Encoding Settings Reference

| Setting | Default | Description |
|---------|---------|-------------|
| `CRF` | 28 | Quality (0-63, lower = better quality) |
| `PRESET` | 6 | Speed (0=slowest/best, 13=fastest) |
| `WORKERS` | 4 | Parallel encoding workers |

**SVT-AV1-HDR specific params (auto-enabled):**
- `--tune 0` - Psychovisual optimization (VQ mode)
- `--variance-boost-curve 3` - HDR contrast preservation

---

## Tdarr Docker Setup

### Quick Start

1. **Build the custom Docker image:**
   ```bash
   ./build.sh
   ```

2. **Start Tdarr:**
   ```bash
   podman-compose up -d
   ```

3. **Access the Web UI:**
   Open http://localhost:8265

### Files

- `Dockerfile` - Custom image with FFmpeg-SVT-AV1-HDR
- `docker-compose.yaml` - Container configuration
- `build.sh` - Build script
- `tdarr/server/Tdarr/Plugins/Local/` - Custom Tdarr plugins

### Using the SVT-AV1-HDR Encoder

#### Via Custom Plugin

A custom Tdarr plugin `Tdarr_Plugin_SVT_AV1_HDR` is included with:

- Automatic HDR detection
- PQ-optimized encoding for HDR content
- Configurable CRF, preset, and tune
- Audio passthrough or re-encoding
- HDR metadata preservation

#### Via Command Line (in container)

```bash
# Enter the container
podman exec -it tdarr bash

# Test the encoder
ffmpeg-svt-av1-hdr -encoders 2>/dev/null | grep svt

# Example encode command
ffmpeg-svt-av1-hdr -i input.mkv \
  -c:v libsvtav1 \
  -crf 30 \
  -preset 4 \
  -svtav1-params "tune=4:enable-variance-boost=1:variance-boost-curve=3" \
  -pix_fmt yuv420p10le \
  -c:a copy \
  output.mkv
```

---

## Recommended Settings

### For HDR Content with Film Grain
```
Tune: 4 (Film Grain)
CRF: 25-35 (start with 30)
Preset: 2 (highly recommended for film grain)
```

### For General HDR Content
```
Tune: 0 (VQ)
CRF: 28-35 (start with 32)
Preset: 4-6
```

### For SDR Content
```
Tune: 0 (VQ)
CRF: 25-32
Preset: 4-6
```

---

## FFmpeg Paths (Docker)

- **Custom FFmpeg (SVT-AV1-HDR):** `/opt/ffmpeg-svt-av1-hdr/bin/ffmpeg`
- **Symlinks:** `ffmpeg-svt-av1-hdr`, `tdarr-ffmpeg-hdr`
- **Default Tdarr FFmpeg:** `tdarr-ffmpeg` (standard build)

---

## Credits

- [SVT-AV1-HDR](https://github.com/juliobbv-p/svt-av1-hdr) by juliobbv-p
- [FFmpeg Builds](https://github.com/QuickFatHedgehog/FFmpeg-Builds-SVT-AV1-HDR) by QuickFatHedgehog
- [Tdarr](https://github.com/HaveAGitGat/Tdarr) by HaveAGitGat
- [av1an](https://github.com/master-of-zen/Av1an) by master-of-zen