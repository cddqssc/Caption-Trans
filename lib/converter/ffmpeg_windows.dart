import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:flutter/foundation.dart';

/// FFmpeg converter for Windows.
///
/// Converts media into 16kHz mono 16-bit PCM WAV suitable for speech recognition.
class FFmpegWindowsConverter {
  FFmpegWindowsConverter._();

  static String _escapeArgument(String path) {
    final escaped = path.replaceAll('"', r'\"');
    return '"$escaped"';
  }

  static Future<void> convertToWav({
    required String inputPath,
    required String outputPath,
  }) async {
    final List<String> arguments = [
      '-y',
      '-i',
      _escapeArgument(inputPath),
      '-map',
      '0:a:0',
      '-af',
      'aresample=async=1:first_pts=0',
      '-ar',
      '16000',
      '-ac',
      '1',
      '-c:a',
      'pcm_s16le',
      _escapeArgument(outputPath),
    ];

    debugPrint('[FFMPEG][Windows] $inputPath -> $outputPath');

    final FFmpegSession session = FFmpegKit.execute(arguments.join(' '));
    final int returnCode = session.getReturnCode();
    if (returnCode == 0) {
      return;
    }

    final String? logs = session.getOutput();
    throw Exception(
      'FFmpeg conversion failed on Windows (code: $returnCode). ${logs ?? ''}',
    );
  }
}
