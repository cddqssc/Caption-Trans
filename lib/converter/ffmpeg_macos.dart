import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';

/// FFmpeg-based implementation of [WhisperAudioConverter].
///
/// This package decouples FFmpeg from the core whisper_ggml_plus engine
/// to prevent version conflicts with other FFmpeg-related packages.
class FFmpegMacOsConverter implements WhisperAudioConverter {
  /// Internal private constructor.
  FFmpegMacOsConverter._();

  /// Registers this FFmpeg converter to the [WhisperController].
  ///
  /// Call this once during app initialization (e.g., in `main()`).
  /// Once registered, [WhisperController.transcribe] will automatically
  /// use FFmpeg to convert non-WAV files to the required 16kHz mono format.
  static void register() {
    WhisperController.registerAudioConverter(FFmpegMacOsConverter._());
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
      '⚙️  [WHISPER FFMPEG] Starting conversion: ${input.path} -> $outputPath',
    );

    // Execute FFmpeg command
    final FFmpegSession session = await FFmpegKit.execute(arguments.join(' '));
    final ReturnCode? returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint('✅ [WHISPER FFMPEG] Conversion successful');
      return audioOutput;
    } else if (ReturnCode.isCancel(returnCode)) {
      debugPrint('⚠️  [WHISPER FFMPEG] Conversion canceled by user');
    } else {
      debugPrint(
        '❌ [WHISPER FFMPEG] Conversion failed with returnCode ${returnCode?.getValue()}',
      );
      final String? logs = await session.getOutput();
      if (logs != null) {
        debugPrint('--- FFmpeg Logs ---');
        debugPrint(logs);
        debugPrint('-------------------');
      }
    }

    return null;
  }
}
