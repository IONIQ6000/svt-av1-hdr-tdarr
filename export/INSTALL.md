# SVT-AV1-HDR Tdarr Plugin - Installation Guide

## Requirements

- Docker or Podman
- Tdarr (will be set up with custom image)

## Quick Setup on New System

### 1. Build the Custom Docker Image

```bash
# Make build script executable
chmod +x build.sh

# Build the image (downloads FFmpeg with SVT-AV1-HDR)
./build.sh
```

### 2. Start Tdarr

```bash
# Edit docker-compose.yaml first to set your media path
# Change /path/to/your/media to your actual media folder

# For Podman:
podman-compose up -d

# For Docker:
docker-compose up -d
```

### 3. Install the Plugin

Copy the plugin file to Tdarr's local plugins folder:

```bash
# The plugin goes in: <tdarr_data>/server/Tdarr/Plugins/Local/
cp Tdarr_Plugin_SVT_AV1_HDR.js ./tdarr/server/Tdarr/Plugins/Local/
```

Or manually:
1. Open Tdarr Web UI (http://localhost:8265)
2. Go to Plugins → Local
3. Create new plugin and paste the contents of `Tdarr_Plugin_SVT_AV1_HDR.js`

### 4. Configure the Plugin

In Tdarr, create a Flow or Library with the plugin:

**Recommended settings:**

| Content Type | Tune | CRF | Preset |
|--------------|------|-----|--------|
| General SDR | 0 (VQ) | 32-38 | 4-6 |
| General HDR | 0 (VQ) | 30-35 | 4-6 |
| Film Grain | 4 (Film Grain) | 25-35 | 2 |

## Files Included

- `Tdarr_Plugin_SVT_AV1_HDR.js` - The Tdarr plugin
- `Dockerfile` - Custom image with SVT-AV1-HDR FFmpeg
- `docker-compose.yaml` - Container configuration
- `build.sh` - Build script for the custom image

## Verify SVT-AV1-HDR

To confirm the encoder is SVT-AV1-HDR:

```bash
# Enter container
podman exec -it tdarr bash

# Check encoder version
/opt/ffmpeg-svt-av1-hdr/bin/ffmpeg -f lavfi -i nullsrc=s=64x64:d=1 -c:v libsvtav1 -f null - 2>&1 | grep "SVT \[version\]"

# Should output:
# SVT-AV1-HDR Encoder Lib v3.x.x
```

## FFmpeg Paths

- Custom FFmpeg: `/opt/ffmpeg-svt-av1-hdr/bin/ffmpeg`
- Symlink: `ffmpeg-svt-av1-hdr`

## Credits

- [SVT-AV1-HDR](https://github.com/juliobbv-p/svt-av1-hdr) by juliobbv-p
- [FFmpeg Builds](https://github.com/QuickFatHedgehog/FFmpeg-Builds-SVT-AV1-HDR) by QuickFatHedgehog
