import 'dart:io';

import '../../models/whisper_runtime_info.dart';
import '../../models/subtitle_segment.dart';
import '../../models/transcription_result.dart';
import '../audio/media_to_wav_converter.dart';
import 'whisperx_sidecar.dart';

class _WhisperExecutionConfig {
  final String asrDevice;
  final String vadDevice;
  final String alignDevice;
  final String computeType;
  final int batchSize;
  final bool usingGpu;
  final bool usesCuda;
  final String modeLabel;
  final String? deviceName;
  final String? statusDetail;

  const _WhisperExecutionConfig({
    required this.asrDevice,
    required this.vadDevice,
    required this.alignDevice,
    required this.computeType,
    required this.batchSize,
    required this.usingGpu,
    required this.usesCuda,
    required this.modeLabel,
    required this.deviceName,
    this.statusDetail,
  });
}

/// Service for transcribing media using WhisperX through a local Python sidecar.
class WhisperService {
  static const Map<String, String> modelMap = {
    'tiny': 'tiny',
    'base': 'base',
    'small': 'small',
    'medium': 'medium',
    'large-v3': 'large-v3',
    'large-v3-turbo': 'large-v3-turbo',
  };

  static const String _cpuDevice = 'cpu';
  static const String _mpsDevice = 'mps';
  static const String _cpuComputeType = 'int8';
  static const int _cpuBatchSize = 8;

  final WhisperXSidecar _sidecar = WhisperXSidecar();
  final MediaToWavConverter _wavConverter = MediaToWavConverter();

  String? _currentModel;

  /// Prepare sidecar runtime resources with phase-aware status updates.
  ///
  /// Only the actual runtime download phase reports determinate byte progress.
  Future<void> downloadModel(
    String modelName, {
    void Function(int received, int total)? onDownloadProgress,
    void Function(String phase, double? progress)? onPreparationState,
  }) async {
    final String? whisperxModel = modelMap[modelName];
    if (whisperxModel == null) {
      throw ArgumentError('Unknown model: $modelName');
    }

    await _sidecar.ensureStarted(
      onBootstrapStatus: (phase) {
        onPreparationState?.call(phase, null);
      },
      onRuntimeDownloadProgress: (received, total) {
        onDownloadProgress?.call(received, total);
        onPreparationState?.call(
          'downloading_runtime',
          total > 0 ? received / total : null,
        );
      },
    );
  }

  /// Ensure sidecar is ready and mark the selected model for next transcription.
  ///
  /// WhisperX model weights are loaded lazily on the first transcribe request.
  Future<void> loadModel(String modelName) async {
    final String? whisperxModel = modelMap[modelName];
    if (whisperxModel == null) {
      throw ArgumentError('Unknown model: $modelName');
    }

    await _sidecar.ensureStarted();
    _currentModel = modelName;
  }

  /// Convert input media into WhisperX-ready WAV.
  Future<String> transcodeToWav(String mediaPath) {
    return _wavConverter.ensureWhisperxWav(mediaPath);
  }

  /// Transcribe already-prepared WAV using loaded model (no fake progress).
  Future<TranscriptionResult> transcribeWav(
    String wavPath, {
    String language = 'auto',
    void Function(String status, String? detail)? onStatus,
    void Function(String line)? onLog,
    void Function(WhisperRuntimeInfo info)? onRuntimeInfo,
  }) async {
    final String? selectedModel = _currentModel;
    if (selectedModel == null) {
      throw StateError('No model loaded. Call loadModel() first.');
    }

    final String whisperxModel = modelMap[selectedModel]!;
    final Map<String, dynamic> payload = await _transcribeWithFallbacks(
      wavPath: wavPath,
      modelName: whisperxModel,
      language: language == 'auto' ? null : language,
      onStatus: onStatus,
      onLog: onLog,
      onRuntimeInfo: onRuntimeInfo,
    );
    return _parseTranscriptionPayload(payload, requestedLanguage: language);
  }

  Future<WhisperRuntimeInfo> inspectRuntime({required String modelName}) async {
    final String whisperxModel = modelMap[modelName] ?? modelName;
    final _WhisperExecutionConfig config = await _resolveExecutionConfig(
      whisperxModel,
    );
    return _buildRuntimeInfo(config);
  }

  Future<Map<String, dynamic>> _transcribeWithFallbacks({
    required String wavPath,
    required String modelName,
    required String? language,
    void Function(String status, String? detail)? onStatus,
    void Function(String line)? onLog,
    void Function(WhisperRuntimeInfo info)? onRuntimeInfo,
  }) async {
    final _WhisperExecutionConfig primaryConfig = await _resolveExecutionConfig(
      modelName,
    );

    try {
      return await _transcribeWithConfig(
        wavPath: wavPath,
        modelName: modelName,
        language: language,
        config: primaryConfig,
        onStatus: onStatus,
        onLog: onLog,
        onRuntimeInfo: onRuntimeInfo,
      );
    } catch (error) {
      if (primaryConfig.usesCuda) {
        if (!_looksLikeCudaFailure(error)) {
          rethrow;
        }

        final _WhisperExecutionConfig? degradedConfig =
            _buildDegradedCudaConfig(primaryConfig);
        if (degradedConfig != null) {
          await _restartSidecarForRetry();
          try {
            return await _transcribeWithConfig(
              wavPath: wavPath,
              modelName: modelName,
              language: language,
              config: degradedConfig,
              onStatus: onStatus,
              onLog: onLog,
              onRuntimeInfo: onRuntimeInfo,
            );
          } catch (retryError) {
            if (!_looksLikeCudaFailure(retryError)) {
              rethrow;
            }
          }
        }

        await _restartSidecarForRetry();
        return _transcribeWithConfig(
          wavPath: wavPath,
          modelName: modelName,
          language: language,
          config: _cpuConfig(
            statusDetail:
                'CUDA failed, falling back to CPU ($_cpuComputeType, batch=$_cpuBatchSize)',
          ),
          onStatus: onStatus,
          onLog: onLog,
          onRuntimeInfo: onRuntimeInfo,
        );
      }

      if (!primaryConfig.usingGpu || !_looksLikeMpsFailure(error)) {
        rethrow;
      }

      await _restartSidecarForRetry();
      return _transcribeWithConfig(
        wavPath: wavPath,
        modelName: modelName,
        language: language,
        config: _cpuConfig(
          statusDetail:
              'MPS failed, falling back to CPU ($_cpuComputeType, batch=$_cpuBatchSize)',
        ),
        onStatus: onStatus,
        onLog: onLog,
        onRuntimeInfo: onRuntimeInfo,
      );
    }
  }

  Future<Map<String, dynamic>> _transcribeWithConfig({
    required String wavPath,
    required String modelName,
    required String? language,
    required _WhisperExecutionConfig config,
    void Function(String status, String? detail)? onStatus,
    void Function(String line)? onLog,
    void Function(WhisperRuntimeInfo info)? onRuntimeInfo,
  }) async {
    onRuntimeInfo?.call(await _buildRuntimeInfo(config));
    onStatus?.call('preparing_model', config.statusDetail);
    final Map<String, dynamic> asrOptions = _buildAsrOptions(language);
    final Map<String, dynamic> vadOptions = _buildVadOptions(language);
    final Map<String, dynamic> segmentationOptions = _buildSegmentationOptions(
      language,
    );
    return _sidecar.transcribe(
      wavPath: wavPath,
      modelName: modelName,
      language: language,
      device: config.asrDevice,
      vadDevice: config.vadDevice,
      alignDevice: config.alignDevice,
      computeType: config.computeType,
      batchSize: config.batchSize,
      noAlign: false,
      asrOptions: asrOptions.isEmpty ? null : asrOptions,
      vadOptions: vadOptions.isEmpty ? null : vadOptions,
      segmentationOptions: segmentationOptions.isEmpty
          ? null
          : segmentationOptions,
      onStatus: onStatus,
      onLog: onLog,
    );
  }

  Map<String, dynamic> _buildAsrOptions(String? language) {
    switch (_normalizeLanguageCode(language)) {
      case 'ja':
        return const <String, dynamic>{
          'initial_prompt': '句読点を含めて自然な文として書き起こしてください。',
        };
      default:
        return const <String, dynamic>{};
    }
  }

  Map<String, dynamic> _buildVadOptions(String? language) {
    switch (_normalizeLanguageCode(language)) {
      case 'ja':
        return const <String, dynamic>{};
      default:
        return const <String, dynamic>{};
    }
  }

  Map<String, dynamic> _buildSegmentationOptions(String? language) {
    switch (_normalizeLanguageCode(language)) {
      case 'ja':
        return const <String, dynamic>{
          'split_on_pause': true,
          'pause_threshold_sec': 0.55,
          'max_segment_duration_sec': 6.0,
          'max_segment_chars': 30,
          'min_split_chars': 6,
          'prefer_punctuation_split': true,
        };
      default:
        return const <String, dynamic>{};
    }
  }

  String? _normalizeLanguageCode(String? language) {
    final String normalized = (language ?? '').trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'auto') {
      return null;
    }
    return normalized;
  }

  Future<_WhisperExecutionConfig> _resolveExecutionConfig(
    String whisperxModel,
  ) async {
    if (Platform.isMacOS && _isArm64Process()) {
      final WhisperXRuntimeProbe probe = await _loadRuntimeProbe();
      if (probe.canUseMps) {
        return const _WhisperExecutionConfig(
          asrDevice: _cpuDevice,
          vadDevice: _mpsDevice,
          alignDevice: _mpsDevice,
          computeType: _cpuComputeType,
          batchSize: _cpuBatchSize,
          usingGpu: true,
          usesCuda: false,
          modeLabel: 'Mixed CPU + MPS',
          deviceName: 'Apple Metal (MPS)',
          statusDetail:
              'Using CPU ASR with MPS-accelerated VAD and alignment (int8, batch=8)',
        );
      }

      final String statusDetail = probe.mpsBuilt
          ? 'MPS is unavailable on this machine, using CPU ($_cpuComputeType, batch=$_cpuBatchSize)'
          : 'Installed PyTorch runtime does not expose MPS, using CPU ($_cpuComputeType, batch=$_cpuBatchSize)';
      return _cpuConfig(statusDetail: statusDetail);
    }

    if (!Platform.isWindows) {
      return _cpuConfig();
    }

    final WhisperXRuntimeProbe probe = await _loadRuntimeProbe();
    if (!probe.canUseCuda) {
      return _cpuConfig();
    }

    final String computeType = _selectCudaComputeType(probe.cudaComputeTypes);
    final int batchSize = _selectCudaBatchSize(whisperxModel);
    final String deviceName = (probe.cudaDeviceName?.trim().isNotEmpty ?? false)
        ? probe.cudaDeviceName!.trim()
        : 'CUDA GPU';

    return _WhisperExecutionConfig(
      asrDevice: 'cuda',
      vadDevice: 'cuda',
      alignDevice: 'cuda',
      computeType: computeType,
      batchSize: batchSize,
      usingGpu: true,
      usesCuda: true,
      modeLabel: 'CUDA GPU',
      deviceName: deviceName,
      statusDetail:
          'Using $deviceName on CUDA ($computeType, batch=$batchSize)',
    );
  }

  Future<WhisperXRuntimeProbe> _loadRuntimeProbe() async {
    return _sidecar.probeRuntime();
  }

  Future<WhisperRuntimeInfo> _buildRuntimeInfo(
    _WhisperExecutionConfig config,
  ) async {
    final WhisperXRuntimeProbe? probe =
        (Platform.isWindows || (Platform.isMacOS && _isArm64Process()))
        ? await _loadRuntimeProbe()
        : null;

    final bool cudaAvailable = probe?.cudaAvailable == true;
    final String? torchCudaVersion = probe?.torchCudaVersion;
    final String modeLabel = !config.usingGpu && cudaAvailable
        ? 'CPU fallback'
        : config.modeLabel;

    return WhisperRuntimeInfo(
      modeLabel: modeLabel,
      deviceName: config.deviceName,
      computeType: config.computeType,
      batchSize: config.batchSize,
      usingGpu: config.usingGpu,
      cudaAvailable: cudaAvailable,
      torchCudaVersion: torchCudaVersion,
      note: config.statusDetail,
    );
  }

  _WhisperExecutionConfig _cpuConfig({String? statusDetail}) {
    return _WhisperExecutionConfig(
      asrDevice: _cpuDevice,
      vadDevice: _cpuDevice,
      alignDevice: _cpuDevice,
      computeType: _cpuComputeType,
      batchSize: _cpuBatchSize,
      usingGpu: false,
      usesCuda: false,
      modeLabel: 'CPU',
      deviceName: null,
      statusDetail: statusDetail,
    );
  }

  _WhisperExecutionConfig? _buildDegradedCudaConfig(
    _WhisperExecutionConfig config,
  ) {
    if (!config.usesCuda) {
      return null;
    }

    final int smallerBatchSize = config.batchSize > 4
        ? config.batchSize ~/ 2
        : 4;
    if (config.computeType == 'int8' && smallerBatchSize >= config.batchSize) {
      return null;
    }

    return _WhisperExecutionConfig(
      asrDevice: 'cuda',
      vadDevice: 'cuda',
      alignDevice: 'cuda',
      computeType: 'int8',
      batchSize: smallerBatchSize,
      usingGpu: true,
      usesCuda: true,
      modeLabel: 'CUDA GPU',
      deviceName: config.deviceName,
      statusDetail:
          'CUDA init failed or VRAM is low, retrying lighter GPU mode (int8, batch=$smallerBatchSize)',
    );
  }

  String _selectCudaComputeType(List<String> computeTypes) {
    final Set<String> normalized = computeTypes
        .map((String item) => item.trim().toLowerCase())
        .where((String item) => item.isNotEmpty)
        .toSet();

    for (final String candidate in <String>[
      'float16',
      'int8_float16',
      'int8',
      'float32',
    ]) {
      if (normalized.contains(candidate)) {
        return candidate;
      }
    }

    return 'float16';
  }

  int _selectCudaBatchSize(String whisperxModel) {
    if (whisperxModel == 'medium' || whisperxModel.startsWith('large')) {
      return 8;
    }
    return 16;
  }

  bool _looksLikeCudaFailure(Object error) {
    final String lower = error.toString().toLowerCase();
    return <String>[
      'cuda',
      'cudnn',
      'cublas',
      'ctranslate2',
      'compute type',
      'out of memory',
      'insufficient memory',
      'not enough memory',
      'device-side assert',
      'failed to load library',
      'dll load failed',
    ].any(lower.contains);
  }

  bool _looksLikeMpsFailure(Object error) {
    final String lower = error.toString().toLowerCase();
    return <String>[
      'mps',
      'metal',
      'not implemented for mps',
      'placeholder storage has not been allocated on mps',
      'mps backend out of memory',
      'does not include mps support',
      'is not available on this machine',
    ].any(lower.contains);
  }

  bool _isArm64Process() {
    final String version = Platform.version.toLowerCase();
    return version.contains('arm64') || version.contains('aarch64');
  }

  Future<void> _restartSidecarForRetry() async {
    await _sidecar.dispose();
  }

  Future<void> cleanupTempWav(
    String wavPath, {
    required String originalMediaPath,
  }) async {
    if (wavPath == originalMediaPath) return;
    final File file = File(wavPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  TranscriptionResult _parseTranscriptionPayload(
    Map<String, dynamic> payload, {
    required String requestedLanguage,
  }) {
    final List<dynamic> rawSegments =
        (payload['segments'] as List<dynamic>?) ?? [];
    final List<SubtitleSegment> segments = <SubtitleSegment>[];
    for (int i = 0; i < rawSegments.length; i++) {
      final dynamic raw = rawSegments[i];
      if (raw is! Map<String, dynamic>) {
        continue;
      }

      final int startMs = (((raw['start'] as num?) ?? 0).toDouble() * 1000)
          .round();
      final int endMs = (((raw['end'] as num?) ?? 0).toDouble() * 1000).round();
      final String text = ((raw['text'] as String?) ?? '').trim();
      if (text.isEmpty) continue;

      segments.add(
        SubtitleSegment(
          index: i + 1,
          startTime: Duration(milliseconds: startMs),
          endTime: Duration(milliseconds: endMs < startMs ? startMs : endMs),
          text: text,
        ),
      );
    }

    final String detectedLanguage =
        (payload['language'] as String?)?.trim().isNotEmpty == true
        ? (payload['language'] as String)
        : (requestedLanguage == 'auto' ? 'unknown' : requestedLanguage);

    final Duration duration = (() {
      final num? value = payload['duration_sec'] as num?;
      if (value == null) {
        if (segments.isEmpty) return Duration.zero;
        return segments.last.endTime;
      }
      return Duration(milliseconds: (value.toDouble() * 1000).round());
    })();

    return TranscriptionResult(
      language: detectedLanguage,
      duration: duration,
      segments: segments,
    );
  }

  bool get isModelLoaded => _currentModel != null;
  String? get loadedModelName => _currentModel;

  Future<void> dispose() async {
    await _sidecar.dispose();
    _currentModel = null;
  }
}
