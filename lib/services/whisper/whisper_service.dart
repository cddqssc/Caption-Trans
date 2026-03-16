import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';
import '../../models/subtitle_segment.dart';
import '../../models/transcription_result.dart';
import 'model_manager.dart';

/// Service for transcribing audio/video using Whisper (whisper.cpp via whisper_ggml_plus).
///
/// Requires [WhisperFFmpegConverter.register()] to be called in main() so that
/// non-WAV files (including video files) are automatically converted.
class WhisperService {
  final WhisperController _controller = WhisperController();
  final ModelManager _modelManager = ModelManager();
  WhisperModel? _currentModel;

  /// Map from string model names to WhisperModel enum values.
  static const Map<String, WhisperModel> modelMap = {
    'tiny': WhisperModel.tiny,
    'base': WhisperModel.base,
    'small': WhisperModel.small,
    'medium': WhisperModel.medium,
    'large-v3': WhisperModel.large,
    'large-v3-turbo': WhisperModel.largeV3Turbo,
  };

  ModelManager get modelManager => _modelManager;

  /// Download a Whisper model with progress reporting.
  Future<void> loadModel(
    String modelName, {
    void Function(int received, int total)? onDownloadProgress,
  }) async {
    final model = modelMap[modelName];
    if (model == null) {
      throw ArgumentError('Unknown model: $modelName');
    }

    // Download model with progress
    await _modelManager.downloadModel(
      model,
      onProgress: onDownloadProgress,
    );
    _currentModel = model;
  }

  /// Transcribe a media file (video or audio) and return structured results.
  ///
  /// The file can be any format supported by FFmpeg — the registered
  /// WhisperFFmpegConverter automatically converts to 16kHz mono WAV.
  Future<TranscriptionResult> transcribe(
    String mediaPath, {
    String language = 'auto',
    void Function(int progress)? onProgress,
  }) async {
    if (_currentModel == null) {
      throw StateError('No model loaded. Call loadModel() first.');
    }

    final result = await _controller.transcribe(
      model: _currentModel!,
      audioPath: mediaPath,
      lang: language,
      withTimestamps: true,
      convert: true, // Auto-convert via registered FFmpeg converter
      onProgress: onProgress,
    );

    if (result == null) {
      throw Exception('Transcription returned null');
    }

    final responseSegments = result.transcription.segments ?? [];

    final segments = <SubtitleSegment>[];
    for (var i = 0; i < responseSegments.length; i++) {
      final seg = responseSegments[i];
      segments.add(SubtitleSegment(
        index: i + 1,
        startTime: seg.fromTs,
        endTime: seg.toTs,
        text: seg.text.trim(),
      ));
    }

    return TranscriptionResult(
      language: language,
      duration: segments.isNotEmpty ? segments.last.endTime : Duration.zero,
      segments: segments,
    );
  }

  bool get isModelLoaded => _currentModel != null;
  String? get loadedModelName => _currentModel?.modelName;

  Future<void> dispose() async {
    if (_currentModel != null) {
      await _controller.dispose(model: _currentModel!);
    }
    _currentModel = null;
  }
}
