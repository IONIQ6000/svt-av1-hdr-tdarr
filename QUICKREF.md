# Quick Reference: av1an + SVT-AV1-HDR

## TL;DR - Just Run This

```bash
# First time setup (in toolbox)
toolbox create encoding && toolbox enter encoding
./setup-av1an-svt-hdr.sh
source ~/.bashrc

# Encode
CRF=28 PRESET=6 WORKERS=8 ./av1an-svt-hdr-encode.sh input.mkv output.mkv
```

---

## Environment Variables (Must Be Set!)

```bash
export LD_LIBRARY_PATH="$HOME/.local/lib64:$LD_LIBRARY_PATH"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export VAPOURSYNTH_PLUGIN_PATH="$HOME/.local/lib/vapoursynth:/usr/lib64/vapoursynth"
```

---

## Encoding Options

| Variable | Default | Description |
|----------|---------|-------------|
| `CRF` | 28 | Quality (0-63, lower = better) |
| `PRESET` | 6 | Speed (0-13, lower = slower/better) |
| `WORKERS` | 4 | Parallel workers |

**Examples:**
```bash
# High quality, slower
CRF=25 PRESET=4 WORKERS=8 ./av1an-svt-hdr-encode.sh in.mkv out.mkv

# Balanced
CRF=28 PRESET=6 WORKERS=8 ./av1an-svt-hdr-encode.sh in.mkv out.mkv

# Fast preview
CRF=35 PRESET=10 WORKERS=12 ./av1an-svt-hdr-encode.sh in.mkv out.mkv
```

---

## Verification Commands

```bash
# Check encoder
SvtAv1EncApp --version

# Check VapourSynth
python3 -c "import vapoursynth as vs; c=vs.core; print('lsmas:', hasattr(c,'lsmas'))"

# Check av1an
av1an --version
```

---

## Common Fixes

| Error | Fix |
|-------|-----|
| `libSvtAv1Enc.so.3 not found` | `export LD_LIBRARY_PATH="$HOME/.local/lib64:$LD_LIBRARY_PATH"` |
| av1an hangs at 0% | `sudo dnf copr enable flawlessmedia/av-rpm && sudo dnf install vapoursynth-plugin-l-smash` |
| `Failed to get VSScript API` | `sudo dnf install python3-vapoursynth` |
| Chunks are 0 bytes | Set `LD_LIBRARY_PATH` (see above) |

---

## File Locations

| What | Where |
|------|-------|
| Encoder | `~/.local/bin/SvtAv1EncApp` |
| Library | `~/.local/lib64/libSvtAv1Enc.so.3` |
| av1an | `~/.cargo/bin/av1an` |
| FFmpeg | `~/.local/bin/ffmpeg` |
| Temp files | `/tmp/av1an-*/` |

---

## Recommended CRF by Content

| Content | CRF | Notes |
|---------|-----|-------|
| 4K HDR Film | 28-32 | Higher = smaller file |
| 1080p HDR | 26-30 | |
| Animation | 24-28 | Animation compresses well |
| Grain-heavy | 30-35 | Higher to preserve grain |
