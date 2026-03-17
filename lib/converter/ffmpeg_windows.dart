import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';

/// FFmpeg-based implementation of [WhisperAudioConverter] for Windows.
class FFmpegWindowsConverter implements WhisperAudioConverter {
  /// Internal private constructor.
  FFmpegWindowsConverter._();

  /// Registers this FFmpeg converter to the [WhisperController].
  static void register() {
    WhisperController.registerAudioConverter(FFmpegWindowsConverter._());
  }

  @override
  Future<File?> convert(File input) async {
    // Generate output path by appending .wav to the original filename
    final String outputPath = '${input.path}.wav';
    final File audioOutput = File(outputPath);

    // Clean up if the output file already exists from a previous failed run
    if (await audioOutput.exists()) {
      await audioOutput.delete();
    }

    // FFmpeg arguments optimized for Whisper.cpp:
    // -map 0:a:0 : Select first audio stream explicitly
    // -af aresample=async=1:first_pts=0 : Fill timestamp gaps with silence
    // -ar 16000 : 16kHz sampling rate
    // -ac 1     : Mono channel
    // -c:a pcm_s16le : 16-bit little-endian PCM (WAV)
    final List<String> arguments = [
      '-y',
      '-i',
      '"${input.path}"',
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
      '"$outputPath"',
    ];

    debugPrint(
      '⚙️  [WHISPER FFMPEG WINDOWS] Starting conversion: ${input.path} -> $outputPath',
    );

    // Execute FFmpeg command
    final FFmpegSession session = FFmpegKit.execute(arguments.join(' '));
    final int returnCode = session.getReturnCode();

    if (returnCode == 0) {
      debugPrint('[WHISPER FFMPEG WINDOWS] Conversion successful');
      return audioOutput;
    } else if (returnCode == 255) {
      debugPrint('[WHISPER FFMPEG WINDOWS] Conversion canceled by user');
    } else {
      debugPrint(
        '[WHISPER FFMPEG WINDOWS] Conversion failed with returnCode $returnCode',
      );
      final String? logs = session.getOutput();
      if (logs != null) {
        debugPrint('--- FFmpeg Logs ---');
        debugPrint(logs);
        debugPrint('-------------------');
      }
    }

    return null;
  }
}
