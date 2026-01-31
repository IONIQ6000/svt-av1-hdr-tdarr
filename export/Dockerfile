# Tdarr with SVT-AV1-HDR Custom Encoder
# Based on official Tdarr image with FFmpeg compiled with SVT-AV1-HDR
FROM ghcr.io/haveagitgat/tdarr:latest

LABEL maintainer="custom"
LABEL description="Tdarr with SVT-AV1-HDR encoder for HDR-optimized AV1 encoding"

# Install dependencies for FFmpeg
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Create directory for custom FFmpeg
RUN mkdir -p /opt/ffmpeg-svt-av1-hdr

# Download FFmpeg with SVT-AV1-HDR from QuickFatHedgehog builds
# Using the linux64 GPL build with all codecs
ARG FFMPEG_URL="https://github.com/QuickFatHedgehog/FFmpeg-Builds-SVT-AV1-HDR/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz"

RUN curl -L "${FFMPEG_URL}" -o /tmp/ffmpeg.tar.xz \
    && tar -xf /tmp/ffmpeg.tar.xz -C /opt/ffmpeg-svt-av1-hdr --strip-components=1 \
    && rm /tmp/ffmpeg.tar.xz \
    && chmod +x /opt/ffmpeg-svt-av1-hdr/bin/*

# Create symlinks for the custom FFmpeg binaries with distinct names
RUN ln -sf /opt/ffmpeg-svt-av1-hdr/bin/ffmpeg /usr/local/bin/ffmpeg-svt-av1-hdr \
    && ln -sf /opt/ffmpeg-svt-av1-hdr/bin/ffprobe /usr/local/bin/ffprobe-svt-av1-hdr

# Also make it available as tdarr-ffmpeg-hdr for Tdarr
RUN ln -sf /opt/ffmpeg-svt-av1-hdr/bin/ffmpeg /usr/local/bin/tdarr-ffmpeg-hdr \
    && ln -sf /opt/ffmpeg-svt-av1-hdr/bin/ffprobe /usr/local/bin/tdarr-ffprobe-hdr

# Verify installation
RUN /opt/ffmpeg-svt-av1-hdr/bin/ffmpeg -version \
    && /opt/ffmpeg-svt-av1-hdr/bin/ffmpeg -encoders 2>/dev/null | grep -i svt

# Set library path for FFmpeg
ENV LD_LIBRARY_PATH="/opt/ffmpeg-svt-av1-hdr/lib:${LD_LIBRARY_PATH}"

# Note: Do NOT set USER here - s6-overlay handles user switching internally
