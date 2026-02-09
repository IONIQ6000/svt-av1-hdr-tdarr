# Tdarr with SVT-AV1-HDR Custom Encoder
# Optimized for Linux systems
# Based on official Tdarr image with FFmpeg compiled with SVT-AV1-HDR
FROM ghcr.io/haveagitgat/tdarr:latest

LABEL maintainer="custom"
LABEL description="Tdarr with SVT-AV1-HDR encoder for HDR-optimized AV1 encoding"
LABEL svt-av1-hdr.version="3.1.3"
LABEL org.opencontainers.image.source="https://github.com/juliobbv-p/svt-av1-hdr"

# FFmpeg build URL - linux64 GPL build with all codecs
ARG FFMPEG_URL="https://github.com/QuickFatHedgehog/FFmpeg-Builds-SVT-AV1-HDR/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz"

# Switch to root for installation
USER root

# Install dependencies, download FFmpeg, setup symlinks - all in one layer to minimize image size
RUN set -eux; \
    # Install minimal dependencies
    apt-get update; \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        xz-utils; \
    # Clean apt cache immediately
    rm -rf /var/lib/apt/lists/*; \
    apt-get clean; \
    \
    # Create FFmpeg directory
    mkdir -p /opt/ffmpeg-svt-av1-hdr; \
    \
    # Download and extract FFmpeg with SVT-AV1-HDR
    curl -fsSL "${FFMPEG_URL}" -o /tmp/ffmpeg.tar.xz; \
    tar -xf /tmp/ffmpeg.tar.xz -C /opt/ffmpeg-svt-av1-hdr --strip-components=1; \
    rm -f /tmp/ffmpeg.tar.xz; \
    \
    # Remove unnecessary files to reduce size (docs, man pages)
    rm -rf /opt/ffmpeg-svt-av1-hdr/share/doc 2>/dev/null || true; \
    rm -rf /opt/ffmpeg-svt-av1-hdr/share/man 2>/dev/null || true; \
    \
    # Make binaries executable
    chmod +x /opt/ffmpeg-svt-av1-hdr/bin/*; \
    \
    # Create symlinks for easy access
    ln -sf /opt/ffmpeg-svt-av1-hdr/bin/ffmpeg /usr/local/bin/ffmpeg-svt-av1-hdr; \
    ln -sf /opt/ffmpeg-svt-av1-hdr/bin/ffprobe /usr/local/bin/ffprobe-svt-av1-hdr; \
    ln -sf /opt/ffmpeg-svt-av1-hdr/bin/ffmpeg /usr/local/bin/tdarr-ffmpeg-hdr; \
    ln -sf /opt/ffmpeg-svt-av1-hdr/bin/ffprobe /usr/local/bin/tdarr-ffprobe-hdr; \
    \
    # Verify SVT-AV1-HDR is working
    /opt/ffmpeg-svt-av1-hdr/bin/ffmpeg -version; \
    /opt/ffmpeg-svt-av1-hdr/bin/ffmpeg -encoders 2>/dev/null | grep -i svt

# Set library path for FFmpeg shared libraries
ENV LD_LIBRARY_PATH="/opt/ffmpeg-svt-av1-hdr/lib:${LD_LIBRARY_PATH}"

# Optimize for high-RAM systems - maximize encoding performance
# Allow glibc to use more memory arenas for better multi-threaded performance
ENV MALLOC_ARENA_MAX=0
# SVT-AV1 logging level (1=info)
ENV SVT_LOG_LEVEL=1
# Increase default lookahead for better quality (uses more RAM)
ENV SVT_AV1_LOOKAHEAD=120
# Allow larger memory pools for encoding
ENV MALLOC_MMAP_THRESHOLD_=131072
ENV MALLOC_TRIM_THRESHOLD_=131072
# Disable memory overcommit heuristics - trust the system has enough RAM
ENV MALLOC_MMAP_MAX_=65536

# Note: Do NOT set USER here - s6-overlay handles user switching internally
