import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../models/subtitle_segment.dart';
import '../../models/transcription_result.dart';
import '../../models/whisper_runtime_info.dart';
import '../audio/media_to_wav_converter.dart';

// ---------------------------------------------------------------------------
// Model spec
// ---------------------------------------------------------------------------

class _SherpaModelSpec {
  final String archiveName;
  final String filePrefix;
  final int featureDim;

  const _SherpaModelSpec({
    required this.archiveName,
    required this.filePrefix,
    this.featureDim = 80,
  });

  String get encoderFile => '$filePrefix-encoder.int8.onnx';
  String get decoderFile => '$filePrefix-decoder.int8.onnx';
  String get tokensFile => '$filePrefix-tokens.txt';
}

// ---------------------------------------------------------------------------
// Messages exchanged between main isolate and worker isolate
// ---------------------------------------------------------------------------

class _LoadModelRequest {
  final String encoderPath;
  final String decoderPath;
  final String tokensPath;
  final String language;
  final int featureDim;
  final int numThreads;

  const _LoadModelRequest({
    required this.encoderPath,
    required this.decoderPath,
    required this.tokensPath,
    required this.language,
    required this.featureDim,
    required this.numThreads,
  });
}

class _TranscribeRequest {
  final String wavPath;
  const _TranscribeRequest({required this.wavPath});
}

class _TranscribeResult {
  final String text;
  final List<String> tokens;
  final List<double> timestamps;
  final int audioDurationMs;

  const _TranscribeResult({
    required this.text,
    required this.tokens,
    required this.timestamps,
    required this.audioDurationMs,
  });
}

class _ErrorResult {
  final String message;
  const _ErrorResult(this.message);
}

// Sentinel to signal "model loaded OK"
class _LoadedResult {
  const _LoadedResult();
}

// Sentinel to request shutdown
class _ShutdownRequest {
  const _ShutdownRequest();
}

// ---------------------------------------------------------------------------
// Worker isolate entry point
// ---------------------------------------------------------------------------

void _workerEntryPoint(SendPort mainSendPort) {
  sherpa.initBindings();
  final ReceivePort workerReceive = ReceivePort();
  mainSendPort.send(workerReceive.sendPort);

  sherpa.OfflineRecognizer? recognizer;

  workerReceive.listen((message) {
    if (message is _LoadModelRequest) {
      try {
        recognizer?.free();
        recognizer = null;

        final config = sherpa.OfflineRecognizerConfig(
          feat: sherpa.FeatureConfig(
            sampleRate: 16000,
            featureDim: message.featureDim,
          ),
          model: sherpa.OfflineModelConfig(
            whisper: sherpa.OfflineWhisperModelConfig(
              encoder: message.encoderPath,
              decoder: message.decoderPath,
              language: message.language,
              task: 'transcribe',
              tailPaddings: 500,
              enableTokenTimestamps: true,
            ),
            tokens: message.tokensPath,
            numThreads: message.numThreads,
            provider: 'cpu',
            debug: false,
          ),
        );
        recognizer = sherpa.OfflineRecognizer(config);
        mainSendPort.send(const _LoadedResult());
      } catch (e) {
        mainSendPort.send(_ErrorResult('Failed to load model: $e'));
      }
    } else if (message is _TranscribeRequest) {
      try {
        if (recognizer == null) {
          mainSendPort.send(const _ErrorResult('No model loaded in worker.'));
          return;
        }
        final waveData = sherpa.readWave(message.wavPath);
        final stream = recognizer!.createStream();
        stream.acceptWaveform(
          samples: waveData.samples,
          sampleRate: waveData.sampleRate,
        );
        recognizer!.decode(stream);
        final result = recognizer!.getResult(stream);

        mainSendPort.send(_TranscribeResult(
          text: result.text,
          tokens: List<String>.from(result.tokens),
          timestamps: List<double>.from(result.timestamps),
          audioDurationMs:
              (waveData.samples.length / waveData.sampleRate * 1000).round(),
        ));
        stream.free();
      } catch (e) {
        mainSendPort.send(_ErrorResult('Transcription failed: $e'));
      }
    } else if (message is _ShutdownRequest) {
      recognizer?.free();
      recognizer = null;
      workerReceive.close();
    }
  });
}

// ---------------------------------------------------------------------------
// WhisperService  (main isolate)
// ---------------------------------------------------------------------------

/// Service for transcribing media using Whisper through sherpa-onnx.
///
/// Heavy work (model loading, inference) runs on a persistent background
/// isolate so the UI thread stays responsive.
class WhisperService {
  static const Map<String, _SherpaModelSpec> _modelSpecs = {
    'tiny': _SherpaModelSpec(
      archiveName: 'sherpa-onnx-whisper-tiny',
      filePrefix: 'tiny',
    ),
    'base': _SherpaModelSpec(
      archiveName: 'sherpa-onnx-whisper-base',
      filePrefix: 'base',
    ),
    'small': _SherpaModelSpec(
      archiveName: 'sherpa-onnx-whisper-small',
      filePrefix: 'small',
    ),
    'medium': _SherpaModelSpec(
      archiveName: 'sherpa-onnx-whisper-medium',
      filePrefix: 'medium',
    ),
    'large-v3': _SherpaModelSpec(
      archiveName: 'sherpa-onnx-whisper-large-v3',
      filePrefix: 'large-v3',
      featureDim: 128,
    ),
    'large-v3-turbo': _SherpaModelSpec(
      archiveName: 'sherpa-onnx-whisper-turbo',
      filePrefix: 'turbo',
      featureDim: 128,
    ),
  };

  static const String _modelsReleasesBaseUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models';
  static const String _readyMarker = '.model_ready';

  final MediaToWavConverter _wavConverter = MediaToWavConverter();

  String? _currentModelName;
  String? _currentLanguage;
  int _numThreads = 4;

  // Worker isolate state
  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  ReceivePort? _mainReceivePort;
  StreamSubscription<dynamic>? _workerSubscription;
  Completer<dynamic>? _pendingResponse;

  // ------------------------------------------------------------------
  // Worker isolate lifecycle
  // ------------------------------------------------------------------

  Future<void> _ensureWorkerStarted() async {
    if (_workerSendPort != null) return;

    final completer = Completer<SendPort>();
    _mainReceivePort = ReceivePort();

    _workerSubscription = _mainReceivePort!.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else {
        _pendingResponse?.complete(message);
        _pendingResponse = null;
      }
    });

    _workerIsolate = await Isolate.spawn(
      _workerEntryPoint,
      _mainReceivePort!.sendPort,
    );

    _workerSendPort = await completer.future;
  }

  Future<T> _sendToWorker<T>(Object request) async {
    await _ensureWorkerStarted();
    _pendingResponse = Completer<dynamic>();
    _workerSendPort!.send(request);
    final result = await _pendingResponse!.future;
    if (result is _ErrorResult) {
      throw Exception(result.message);
    }
    return result as T;
  }

  // ------------------------------------------------------------------
  // Download
  // ------------------------------------------------------------------

  Future<void> downloadModel(
    String modelName, {
    void Function(int received, int total)? onDownloadProgress,
    void Function(String phase, double? progress)? onPreparationState,
  }) async {
    final _SherpaModelSpec? spec = _modelSpecs[modelName];
    if (spec == null) {
      throw ArgumentError('Unknown model: $modelName');
    }

    onPreparationState?.call('checking_model', null);
    final Directory modelDir = await _resolveModelDir(spec);

    if (await _isModelReady(modelDir, spec)) {
      onPreparationState?.call('model_ready', 1.0);
      return;
    }

    onPreparationState?.call('downloading_model', 0.0);
    final String archiveUrl =
        '$_modelsReleasesBaseUrl/${spec.archiveName}.tar.bz2';
    final Directory tempDir = await getTemporaryDirectory();
    final File archiveFile = File(
      p.join(tempDir.path, '${spec.archiveName}.tar.bz2'),
    );

    try {
      await _downloadFile(
        Uri.parse(archiveUrl),
        archiveFile,
        onProgress: (received, total) {
          onDownloadProgress?.call(received, total);
          onPreparationState?.call(
            'downloading_model',
            total > 0 ? received / total : null,
          );
        },
      );

      onPreparationState?.call('extracting_model', null);
      if (modelDir.existsSync()) {
        await modelDir.delete(recursive: true);
      }
      await _extractTarBz2(archiveFile, modelDir.parent);
      await File(p.join(modelDir.path, _readyMarker)).writeAsString('');

      onPreparationState?.call('model_ready', 1.0);
    } finally {
      if (archiveFile.existsSync()) {
        try {
          await archiveFile.delete();
        } catch (_) {}
      }
    }
  }

  // ------------------------------------------------------------------
  // Load model (in worker isolate)
  // ------------------------------------------------------------------

  Future<void> loadModel(String modelName, {String? language}) async {
    final _SherpaModelSpec? spec = _modelSpecs[modelName];
    if (spec == null) {
      throw ArgumentError('Unknown model: $modelName');
    }

    final String langCode = _normalizeLanguage(language);
    if (_currentModelName == modelName && _currentLanguage == langCode) {
      return;
    }

    final Directory modelDir = await _resolveModelDir(spec);
    if (!await _isModelReady(modelDir, spec)) {
      throw StateError(
        'Model "$modelName" is not downloaded. Call downloadModel() first.',
      );
    }

    _numThreads = _selectThreadCount();

    await _sendToWorker<_LoadedResult>(_LoadModelRequest(
      encoderPath: p.join(modelDir.path, spec.encoderFile),
      decoderPath: p.join(modelDir.path, spec.decoderFile),
      tokensPath: p.join(modelDir.path, spec.tokensFile),
      language: langCode,
      featureDim: spec.featureDim,
      numThreads: _numThreads,
    ));

    _currentModelName = modelName;
    _currentLanguage = langCode;
  }

  // ------------------------------------------------------------------
  // Transcode
  // ------------------------------------------------------------------

  Future<String> transcodeToWav(String mediaPath) {
    return _wavConverter.ensureWav(mediaPath);
  }

  // ------------------------------------------------------------------
  // Transcribe (in worker isolate)
  // ------------------------------------------------------------------

  Future<TranscriptionResult> transcribeWav(
    String wavPath, {
    String language = 'auto',
    void Function(String status, String? detail)? onStatus,
    void Function(WhisperRuntimeInfo info)? onRuntimeInfo,
  }) async {
    if (_currentModelName == null) {
      throw StateError('No model loaded. Call loadModel() first.');
    }

    onRuntimeInfo?.call(_buildRuntimeInfo());
    onStatus?.call('loading_audio', null);

    // Yield so the UI can paint before we await the worker
    await Future<void>.delayed(Duration.zero);

    onStatus?.call('transcribing', null);

    final _TranscribeResult result = await _sendToWorker<_TranscribeResult>(
      _TranscribeRequest(wavPath: wavPath),
    );

    onStatus?.call('finalizing', null);

    return _parseResult(
      text: result.text,
      tokens: result.tokens,
      timestamps: result.timestamps,
      audioDuration: Duration(milliseconds: result.audioDurationMs),
      requestedLanguage: language,
    );
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  WhisperRuntimeInfo inspectRuntime({required String modelName}) {
    return _buildRuntimeInfo();
  }

  WhisperRuntimeInfo _buildRuntimeInfo() {
    return WhisperRuntimeInfo(
      modeLabel: 'CPU (sherpa-onnx)',
      numThreads: _numThreads,
      note: 'Using sherpa-onnx native runtime',
    );
  }

  String _normalizeLanguage(String? language) {
    final String normalized = (language ?? '').trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'auto') return '';
    return normalized;
  }

  int _selectThreadCount() {
    return Platform.numberOfProcessors.clamp(2, 8);
  }

  Future<Directory> _resolveModelDir(_SherpaModelSpec spec) async {
    final Directory supportDir = await getApplicationSupportDirectory();
    return Directory(
      p.join(supportDir.path, 'sherpa_models', spec.archiveName),
    );
  }

  Future<bool> _isModelReady(
    Directory modelDir,
    _SherpaModelSpec spec,
  ) async {
    if (!modelDir.existsSync()) return false;
    if (!File(p.join(modelDir.path, _readyMarker)).existsSync()) return false;
    final requiredFiles = [spec.encoderFile, spec.decoderFile, spec.tokensFile];
    for (final fileName in requiredFiles) {
      if (!File(p.join(modelDir.path, fileName)).existsSync()) return false;
    }
    return true;
  }

  Future<void> _downloadFile(
    Uri url,
    File output, {
    void Function(int received, int total)? onProgress,
  }) async {
    final HttpClient client = HttpClient();
    client.autoUncompress = false;
    IOSink? sink;
    try {
      final HttpClientRequest request = await client.getUrl(url);
      HttpClientResponse response = await request.close();

      int redirectCount = 0;
      while (response.isRedirect && redirectCount < 10) {
        final String? location = response.headers.value('location');
        if (location == null) break;
        await response.drain<void>();
        final HttpClientRequest redirect =
            await client.getUrl(Uri.parse(location));
        response = await redirect.close();
        redirectCount++;
      }

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode} ($url)');
      }

      final int total = response.contentLength;
      int received = 0;
      sink = output.openWrite();
      await for (final List<int> chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.close();
      sink = null;
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      client.close(force: true);
    }
  }

  Future<void> _extractTarBz2(File archiveFile, Directory destination) async {
    await destination.create(recursive: true);
    final ProcessResult result = await Process.run(
      'tar',
      ['xjf', archiveFile.path, '-C', destination.path],
    );
    if (result.exitCode != 0) {
      throw Exception(
        'Failed to extract model archive.\n${result.stderr}',
      );
    }
  }

  Future<void> cleanupTempWav(
    String wavPath, {
    required String originalMediaPath,
  }) async {
    if (wavPath == originalMediaPath) return;
    final File file = File(wavPath);
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Warning: Failed to clean up temp WAV: $e');
    }
  }

  TranscriptionResult _parseResult({
    required String text,
    required List<String> tokens,
    required List<double> timestamps,
    required Duration audioDuration,
    required String requestedLanguage,
  }) {
    final String trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return TranscriptionResult(
        language: requestedLanguage == 'auto' ? 'unknown' : requestedLanguage,
        duration: audioDuration,
        segments: const [],
      );
    }

    final List<SubtitleSegment> segments;
    if (timestamps.isNotEmpty && tokens.isNotEmpty) {
      segments = _buildSegmentsFromTokens(tokens, timestamps, audioDuration);
    } else {
      segments = [
        SubtitleSegment(
          index: 1,
          startTime: Duration.zero,
          endTime: audioDuration,
          text: trimmedText,
        ),
      ];
    }

    return TranscriptionResult(
      language: requestedLanguage == 'auto' ? 'unknown' : requestedLanguage,
      duration: audioDuration,
      segments: segments,
    );
  }

  List<SubtitleSegment> _buildSegmentsFromTokens(
    List<String> tokens,
    List<double> timestamps,
    Duration audioDuration,
  ) {
    if (tokens.isEmpty) return const [];

    final List<SubtitleSegment> segments = [];
    final StringBuffer currentText = StringBuffer();
    double segmentStart = timestamps.isNotEmpty ? timestamps[0] : 0.0;
    double lastEnd = segmentStart;
    int segmentIndex = 1;

    const double maxSegmentDuration = 8.0;
    const int maxSegmentChars = 80;
    const double pauseThreshold = 0.8;
    const Set<String> sentenceEnders = {
      '.', '!', '?', '\u3002', '\uff01', '\uff1f',
    };

    for (int i = 0; i < tokens.length; i++) {
      final String token = tokens[i];
      final double tokenStart =
          i < timestamps.length ? timestamps[i] : lastEnd;
      final double tokenEnd = i + 1 < timestamps.length
          ? timestamps[i + 1]
          : (tokenStart + 0.1);

      final double gap = tokenStart - lastEnd;
      final double segmentDuration = tokenStart - segmentStart;
      final String trimmedCurrent = currentText.toString().trim();

      bool shouldSplit = false;
      if (trimmedCurrent.isNotEmpty) {
        if (gap >= pauseThreshold) {
          shouldSplit = true;
        } else if (segmentDuration >= maxSegmentDuration) {
          shouldSplit = true;
        } else if (currentText.length >= maxSegmentChars &&
            sentenceEnders
                .contains(trimmedCurrent[trimmedCurrent.length - 1])) {
          shouldSplit = true;
        }
      }

      if (shouldSplit && trimmedCurrent.isNotEmpty) {
        segments.add(SubtitleSegment(
          index: segmentIndex++,
          startTime: Duration(milliseconds: (segmentStart * 1000).round()),
          endTime: Duration(milliseconds: (lastEnd * 1000).round()),
          text: trimmedCurrent,
        ));
        currentText.clear();
        segmentStart = tokenStart;
      }

      currentText.write(token);
      lastEnd = tokenEnd;
    }

    final String remaining = currentText.toString().trim();
    if (remaining.isNotEmpty) {
      segments.add(SubtitleSegment(
        index: segmentIndex,
        startTime: Duration(milliseconds: (segmentStart * 1000).round()),
        endTime: Duration(
          milliseconds: (lastEnd * 1000).round().clamp(
                0,
                audioDuration.inMilliseconds,
              ),
        ),
        text: remaining,
      ));
    }

    return segments;
  }

  bool get isModelLoaded => _currentModelName != null;
  String? get loadedModelName => _currentModelName;

  Future<void> dispose() async {
    if (_workerSendPort != null) {
      _workerSendPort!.send(const _ShutdownRequest());
    }
    await _workerSubscription?.cancel();
    _mainReceivePort?.close();
    _workerIsolate?.kill(priority: Isolate.beforeNextEvent);
    _workerIsolate = null;
    _workerSendPort = null;
    _mainReceivePort = null;
    _workerSubscription = null;
    _pendingResponse = null;
    _currentModelName = null;
    _currentLanguage = null;
  }
}
