import 'dart:io';

import 'package:caption_trans/converter/ffmpeg_macos.dart';
import 'package:caption_trans/converter/ffmpeg_windows.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Converts media input into WAV audio suitable for speech recognition.
class MediaToWavConverter {
  /// Convert [inputPath] to 16kHz mono 16-bit WAV if needed.
  ///
  /// If [inputPath] is already a WAV file, returns [inputPath].
  Future<String> ensureWav(String inputPath) async {
    if (p.extension(inputPath).toLowerCase() == '.wav') {
      return inputPath;
    }

    final tempDir = await getTemporaryDirectory();
    final outputDir = Directory(
      p.join(tempDir.path, 'caption_trans', 'wav_cache'),
    );
    await outputDir.create(recursive: true);

    final outputPath = p.join(
      outputDir.path,
      '${p.basenameWithoutExtension(inputPath)}_${DateTime.now().microsecondsSinceEpoch}.wav',
    );

    if (Platform.isMacOS) {
      await FFmpegMacOsConverter.convertToWav(
        inputPath: inputPath,
        outputPath: outputPath,
      );
      return outputPath;
    }

    if (Platform.isWindows) {
      await FFmpegWindowsConverter.convertToWav(
        inputPath: inputPath,
        outputPath: outputPath,
      );
      return outputPath;
    }

    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}
