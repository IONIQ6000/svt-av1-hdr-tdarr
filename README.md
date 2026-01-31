# Tdarr with SVT-AV1-HDR

Custom Tdarr setup with the SVT-AV1-HDR encoder for psychovisually optimal HDR and SDR AV1 encoding.

## About SVT-AV1-HDR

[SVT-AV1-HDR](https://github.com/juliobbv-p/svt-av1-hdr) is a fork of SVT-AV1 with perceptual enhancements:

- **PQ-optimized Variance Boost**: Custom curve for HDR video with Perceptual Quantizer (PQ) transfer
- **Film Grain Tune (tune 4)**: Optimized for film grain retention and temporal consistency
- **56% smaller files**: Comparable quality at 56.6% the size of standard SVT-AV1 for HDR content

## Quick Start

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

## Files

- `Dockerfile` - Custom image with FFmpeg-SVT-AV1-HDR
- `docker-compose.yaml` - Container configuration
- `build.sh` - Build script
- `tdarr/server/Tdarr/Plugins/Local/` - Custom Tdarr plugins

## Using the SVT-AV1-HDR Encoder

### Via Custom Plugin

A custom Tdarr plugin `Tdarr_Plugin_SVT_AV1_HDR` is included with:

- Automatic HDR detection
- PQ-optimized encoding for HDR content
- Configurable CRF, preset, and tune
- Audio passthrough or re-encoding
- HDR metadata preservation

### Via Command Line (in container)

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

## FFmpeg Paths

- **Custom FFmpeg (SVT-AV1-HDR):** `/opt/ffmpeg-svt-av1-hdr/bin/ffmpeg`
- **Symlinks:** `ffmpeg-svt-av1-hdr`, `tdarr-ffmpeg-hdr`
- **Default Tdarr FFmpeg:** `tdarr-ffmpeg` (standard build)

## Credits

- [SVT-AV1-HDR](https://github.com/juliobbv-p/svt-av1-hdr) by juliobbv-p
- [FFmpeg Builds](https://github.com/QuickFatHedgehog/FFmpeg-Builds-SVT-AV1-HDR) by QuickFatHedgehog
- [Tdarr](https://github.com/HaveAGitGat/Tdarr) by HaveAGitGat
