/* eslint-disable */

/**
 * SVT-AV1-HDR Encoder Plugin for Tdarr
 * 
 * Uses FFmpeg with SVT-AV1-HDR for psychovisually optimal HDR and SDR AV1 encoding.
 * 
 * SVT-AV1-HDR Features:
 * - PQ-optimized Variance Boost for HDR content (curve 3)
 * - Film Grain tune (tune 4) for grainy content
 * - VQ tune (tune 0) for visual quality
 * - Automatic HDR metadata preservation
 * - 10-bit color depth support
 * 
 * Requires: Custom Tdarr image with SVT-AV1-HDR FFmpeg at /opt/ffmpeg-svt-av1-hdr/bin/ffmpeg
 */

const details = () => ({
  id: 'Tdarr_Plugin_SVT_AV1_HDR',
  Stage: 'Pre-processing',
  Name: 'SVT-AV1-HDR Encoder',
  Type: 'Video',
  Operation: 'Transcode',
  Description: `
    Encode video using SVT-AV1-HDR for optimal HDR and SDR quality.
    Uses the custom FFmpeg build with SVT-AV1-HDR encoder.
    
    Features:
    - VQ tune for visual quality (default)
    - Film Grain tune for grainy content
    - PQ-optimized encoding for HDR content
    - Automatic HDR metadata preservation
    - 10-bit color depth output
  `,
  Version: '1.1.0',
  Tags: 'pre-processing,ffmpeg,video,av1,hdr,svt-av1-hdr',
  Inputs: [
    {
      name: 'tune',
      type: 'string',
      defaultValue: '0',
      inputUI: {
        type: 'dropdown',
        options: [
          '0',
          '4',
        ],
      },
      tooltip: 'Tuning mode. 0=VQ (Visual Quality, recommended), 4=Film Grain (for grainy content, use preset 2).',
    },
    {
      name: 'crf',
      type: 'number',
      defaultValue: 35,
      inputUI: {
        type: 'text',
      },
      tooltip: 'CRF value (quality). Lower = better quality, larger file. Recommended: 20-40 for film grain tune, 30-38 for VQ.',
    },
    {
      name: 'preset',
      type: 'string',
      defaultValue: '4',
      inputUI: {
        type: 'dropdown',
        options: ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'],
      },
      tooltip: 'Encoding preset. Lower = slower/better quality. 2-6 recommended for VQ, 2 HIGHLY recommended for Film Grain.',
    },
    {
      name: 'enable_hdr_curve',
      type: 'boolean',
      defaultValue: false,
      inputUI: {
        type: 'dropdown',
        options: ['false', 'true'],
      },
      tooltip: 'Enable PQ-optimized variance boost curve (curve 3) for HDR content. Auto-enabled if HDR detected.',
    },
    {
      name: 'container',
      type: 'string',
      defaultValue: 'mkv',
      inputUI: {
        type: 'dropdown',
        options: ['mkv', 'mp4', 'webm'],
      },
      tooltip: 'Output container format.',
    },
    {
      name: 'audio_codec',
      type: 'string',
      defaultValue: 'copy',
      inputUI: {
        type: 'dropdown',
        options: ['copy', 'aac', 'opus', 'flac'],
      },
      tooltip: 'Audio codec. Use "copy" to preserve original audio.',
    },
    {
      name: 'ffmpeg_path',
      type: 'string',
      defaultValue: '/opt/ffmpeg-svt-av1-hdr/bin/ffmpeg',
      inputUI: {
        type: 'text',
      },
      tooltip: 'Path to FFmpeg with SVT-AV1-HDR support.',
    },
  ],
});

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const plugin = (file, librarySettings, inputs, otherArguments) => {
  const lib = require('../methods/lib')();
  // eslint-disable-next-line @typescript-eslint/no-unused-vars,no-param-reassign
  inputs = lib.loadDefaultValues(inputs, details);
  
  const response = {
    processFile: false,
    preset: '',
    container: `.${inputs.container}`,
    handBrakeMode: false,
    FFmpegMode: true,
    reQueueAfter: false,
    infoLog: '',
  };

  // Check if file is a video
  if (file.fileMedium !== 'video') {
    response.infoLog += '☒ File is not a video. Skipping.\n';
    return response;
  }

  // Get video stream info
  const videoStream = file.ffProbeData?.streams?.find(
    (stream) => stream.codec_type === 'video'
  );

  if (!videoStream) {
    response.infoLog += '☒ No video stream found. Skipping.\n';
    return response;
  }

  // Check if already AV1
  if (videoStream.codec_name === 'av1') {
    response.infoLog += '☑ Video is already AV1. Skipping.\n';
    return response;
  }

  response.infoLog += `☒ Video codec is ${videoStream.codec_name}, will encode to AV1 with SVT-AV1-HDR.\n`;

  // Detect HDR
  const isHDR = detectHDR(videoStream, file);
  if (isHDR) {
    response.infoLog += '☑ HDR content detected. Will use HDR-optimized settings.\n';
  } else {
    response.infoLog += '☐ SDR content detected.\n';
  }

  // Get settings
  const ffmpegPath = inputs.ffmpeg_path || '/opt/ffmpeg-svt-av1-hdr/bin/ffmpeg';
  const crf = inputs.crf || 35;
  const preset = inputs.preset || '4';
  const tune = inputs.tune || '0';
  const audioCodec = inputs.audio_codec || 'copy';
  const enableHdrCurve = inputs.enable_hdr_curve === 'true' || inputs.enable_hdr_curve === true;

  response.infoLog += `☑ Settings: Tune=${tune === '0' ? 'VQ' : 'Film Grain'}, CRF=${crf}, Preset=${preset}\n`;

  // Build SVT-AV1 parameters
  let svtParams = [];
  svtParams.push(`tune=${tune}`);
  
  // Add HDR-specific parameters (PQ curve) if HDR detected or manually enabled
  if (isHDR || enableHdrCurve) {
    svtParams.push('variance-boost-curve=3'); // PQ-optimized curve
    response.infoLog += '☑ PQ variance boost curve enabled for HDR.\n';
  }

  // Build the FFmpeg command
  let ffmpegArgs = [];
  
  ffmpegArgs.push(`<io> -c:v libsvtav1`);
  ffmpegArgs.push(`-crf ${crf}`);
  ffmpegArgs.push(`-preset ${preset}`);
  ffmpegArgs.push(`-pix_fmt yuv420p10le`); // 10-bit output
  
  // Add SVT-AV1 specific params
  if (svtParams.length > 0) {
    ffmpegArgs.push(`-svtav1-params "${svtParams.join(':')}"`);
  }

  // Preserve HDR metadata if present
  if (isHDR) {
    ffmpegArgs.push('-color_primaries bt2020');
    ffmpegArgs.push('-color_trc smpte2084');
    ffmpegArgs.push('-colorspace bt2020nc');
  }

  // Audio handling
  ffmpegArgs.push(`-c:a ${audioCodec}`);
  
  // Copy subtitles if container supports it
  if (inputs.container === 'mkv') {
    ffmpegArgs.push('-c:s copy');
  }
  
  // Map all streams
  ffmpegArgs.push('-map 0');
  
  response.preset = ffmpegArgs.join(' ');
  response.processFile = true;
  
  // Override FFmpeg path
  response.FFmpegPath = ffmpegPath;

  response.infoLog += `☑ Will process with SVT-AV1-HDR encoder.\n`;
  response.infoLog += `☑ FFmpeg: ${ffmpegPath}\n`;

  return response;
};

/**
 * Detect if video is HDR based on metadata
 */
function detectHDR(videoStream, file) {
  // Check color transfer
  const colorTransfer = videoStream.color_transfer || '';
  if (colorTransfer === 'smpte2084' || colorTransfer === 'arib-std-b67') {
    return true; // PQ or HLG
  }

  // Check color primaries
  const colorPrimaries = videoStream.color_primaries || '';
  if (colorPrimaries === 'bt2020') {
    return true;
  }

  // Check for HDR metadata in side data
  if (videoStream.side_data_list) {
    for (const sideData of videoStream.side_data_list) {
      if (sideData.side_data_type?.includes('HDR') ||
          sideData.side_data_type?.includes('Mastering display') ||
          sideData.side_data_type?.includes('Content light level')) {
        return true;
      }
    }
  }

  return false;
}

module.exports.details = details;
module.exports.plugin = plugin;
