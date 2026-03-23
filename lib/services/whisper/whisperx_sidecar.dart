import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'whisperx_runtime.dart';

class WhisperXRuntimeProbe {
  final String platform;
  final String pythonVersion;
  final String whisperxVersion;
  final String? torchVersion;
  final String? torchCudaVersion;
  final bool mpsBuilt;
  final bool mpsAvailable;
  final bool cudaAvailable;
  final int cudaDeviceCount;
  final String? cudaDeviceName;
  final List<String> cudaComputeTypes;
  final int logicalCpuCount;
  final int physicalCpuCount;
  final int recommendedCpuThreads;
  final String? torchError;
  final String? ctranslate2Version;
  final String? ctranslate2Error;
  final String? ctranslate2CudaError;

  const WhisperXRuntimeProbe({
    required this.platform,
    required this.pythonVersion,
    required this.whisperxVersion,
    required this.torchVersion,
    required this.torchCudaVersion,
    required this.mpsBuilt,
    required this.mpsAvailable,
    required this.cudaAvailable,
    required this.cudaDeviceCount,
    required this.cudaDeviceName,
    required this.cudaComputeTypes,
    required this.logicalCpuCount,
    required this.physicalCpuCount,
    required this.recommendedCpuThreads,
    required this.torchError,
    required this.ctranslate2Version,
    required this.ctranslate2Error,
    required this.ctranslate2CudaError,
  });

  bool get canUseCuda =>
      cudaAvailable && cudaDeviceCount > 0 && cudaComputeTypes.isNotEmpty;
  bool get canUseMps => mpsBuilt && mpsAvailable;

  factory WhisperXRuntimeProbe.fromPayload(Map<String, dynamic> payload) {
    final List<String> computeTypes =
        ((payload['cuda_compute_types'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic item) => item.toString().trim().toLowerCase())
            .where((String item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return WhisperXRuntimeProbe(
      platform: (payload['platform'] as String? ?? '').trim().toLowerCase(),
      pythonVersion: (payload['python_version'] as String? ?? '').trim(),
      whisperxVersion: (payload['whisperx_version'] as String? ?? '').trim(),
      torchVersion: (payload['torch_version'] as String?)?.trim(),
      torchCudaVersion: (payload['torch_cuda_version'] as String?)?.trim(),
      mpsBuilt: payload['mps_built'] == true,
      mpsAvailable: payload['mps_available'] == true,
      cudaAvailable: payload['cuda_available'] == true,
      cudaDeviceCount: (payload['cuda_device_count'] as num?)?.toInt() ?? 0,
      cudaDeviceName: (payload['cuda_device_name'] as String?)?.trim(),
      cudaComputeTypes: computeTypes,
      logicalCpuCount: (payload['logical_cpu_count'] as num?)?.toInt() ?? 0,
      physicalCpuCount: (payload['physical_cpu_count'] as num?)?.toInt() ?? 0,
      recommendedCpuThreads:
          (payload['recommended_cpu_threads'] as num?)?.toInt() ?? 0,
      torchError: (payload['torch_error'] as String?)?.trim(),
      ctranslate2Version: (payload['ctranslate2_version'] as String?)?.trim(),
      ctranslate2Error: (payload['ctranslate2_error'] as String?)?.trim(),
      ctranslate2CudaError: (payload['ctranslate2_cuda_error'] as String?)
          ?.trim(),
    );
  }
}

class _PendingRequest {
  final Completer<Map<String, dynamic>> completer;
  final void Function(int progress)? onProgress;
  final void Function(String status, String? detail)? onStatus;
  final void Function(String line)? onLog;

  const _PendingRequest({
    required this.completer,
    this.onProgress,
    this.onStatus,
    this.onLog,
  });
}

/// Long-running local WhisperX process, communicating via JSON lines (stdio).
class WhisperXSidecar {
  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  Completer<void>? _readyCompleter;
  final Map<String, _PendingRequest> _pending = <String, _PendingRequest>{};
  Future<void>? _startFuture;
  int _requestSeq = 0;
  String? _activeRequestForLogs;
  Future<WhisperXRuntimeProbe>? _runtimeProbeFuture;
  String? _startedStartupProfileId;

  Future<void> ensureStarted({
    void Function(int percent)? onBootstrapProgress,
    void Function(int received, int total)? onRuntimeDownloadProgress,
    void Function(String phase)? onBootstrapStatus,
    void Function(String line)? onBootstrapLog,
  }) async {
    final String desiredProfileId = await WhisperXRuntime.instance
        .resolveCurrentStartupProfileId();

    if (_process != null && _startedStartupProfileId == desiredProfileId) {
      return;
    }

    if (_startFuture != null) {
      await _startFuture;
      if (_process != null && _startedStartupProfileId == desiredProfileId) {
        return;
      }
    }

    if (_process != null) {
      await dispose();
    }

    _startFuture = _doStart(
      expectedStartupProfileId: desiredProfileId,
      onBootstrapProgress: onBootstrapProgress,
      onRuntimeDownloadProgress: onRuntimeDownloadProgress,
      onBootstrapStatus: onBootstrapStatus,
      onBootstrapLog: onBootstrapLog,
    );
    try {
      await _startFuture;
    } finally {
      _startFuture = null;
    }
  }

  Future<void> _doStart({
    required String expectedStartupProfileId,
    void Function(int percent)? onBootstrapProgress,
    void Function(int received, int total)? onRuntimeDownloadProgress,
    void Function(String phase)? onBootstrapStatus,
    void Function(String line)? onBootstrapLog,
  }) async {
    final WhisperXRuntimeInfo info = await WhisperXRuntime.instance.ensureReady(
      onProgress: onBootstrapProgress,
      onDownloadProgress: onRuntimeDownloadProgress,
      onStatus: onBootstrapStatus,
      onLog: onBootstrapLog,
    );

    _readyCompleter = Completer<void>();
    onBootstrapStatus?.call('starting_sidecar');
    final process = await Process.start(
      info.pythonExecutable,
      [info.workerScriptPath],
      workingDirectory: p.dirname(info.workerScriptPath),
      environment: <String, String>{
        'PYTHONIOENCODING': 'utf-8',
        'PYTHONUTF8': '1',
        ...info.environment,
      },
      runInShell: false,
    );
    _process = process;
    _startedStartupProfileId = expectedStartupProfileId;

    _stdoutSub = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
          _handleStdoutLine,
          onError: (Object error, StackTrace stackTrace) {
            _handleProcessFailure(
              Exception('WhisperX sidecar stdout decode failed: $error'),
              terminateProcess: true,
            );
          },
        );

    _stderrSub = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
          (line) {
            debugPrint('[WhisperX][stderr] $line');
            final String? id = _activeRequestForLogs;
            if (id == null) return;
            final _PendingRequest? pending = _pending[id];
            pending?.onLog?.call(line);
          },
          onError: (Object error, StackTrace stackTrace) {
            _handleProcessFailure(
              Exception('WhisperX sidecar stderr decode failed: $error'),
              terminateProcess: true,
            );
          },
        );

    process.exitCode.then((code) {
      _handleProcessFailure(
        Exception('WhisperX sidecar exited unexpectedly: $code'),
      );
    });

    await _readyCompleter!.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () =>
          throw Exception('Timed out waiting for WhisperX sidecar startup.'),
    );
  }

  void _handleStdoutLine(String line) {
    if (line.trim().isEmpty) return;

    Map<String, dynamic> message;
    try {
      final dynamic decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      message = decoded;
    } catch (_) {
      // Some Python libraries write plain text to stdout.
      final String? id = _activeRequestForLogs;
      if (id != null) {
        final _PendingRequest? pending = _pending[id];
        pending?.onLog?.call(line);
      }
      return;
    }

    final String type = (message['type'] as String?) ?? '';
    if (type == 'ready') {
      _readyCompleter?.complete();
      return;
    }

    final String? id = message['id'] as String?;
    if (id == null) {
      return;
    }

    final _PendingRequest? pending = _pending[id];
    if (pending == null) {
      return;
    }

    if (type == 'progress') {
      final int progress = (message['progress'] as num?)?.round() ?? 0;
      pending.onProgress?.call(progress.clamp(0, 100));
      return;
    }

    if (type == 'status') {
      final String status = (message['status'] as String?) ?? '';
      if (status.isNotEmpty) {
        final String? detail = message['detail'] as String?;
        pending.onStatus?.call(status, detail);
      }
      return;
    }

    if (type == 'log') {
      final String logLine = (message['line'] as String?)?.trim() ?? '';
      if (logLine.isNotEmpty) {
        pending.onLog?.call(logLine);
      }
      return;
    }

    _pending.remove(id);
    if (_activeRequestForLogs == id) {
      _activeRequestForLogs = null;
    }
    if (type == 'result') {
      final payload = message['payload'];
      if (payload is Map<String, dynamic>) {
        pending.completer.complete(payload);
      } else {
        pending.completer.completeError(
          Exception(
            'WhisperX sidecar returned invalid payload for request $id',
          ),
        );
      }
      return;
    }

    if (type == 'error') {
      final String msg =
          message['message'] as String? ?? 'Unknown WhisperX sidecar error';
      final String trace = message['trace'] as String? ?? '';
      pending.completer.completeError(Exception('$msg\n$trace'));
    }
  }

  void _handleProcessFailure(Exception error, {bool terminateProcess = false}) {
    if (terminateProcess) {
      _process?.kill();
    }

    final readyCompleter = _readyCompleter;
    if (readyCompleter != null && !readyCompleter.isCompleted) {
      readyCompleter.completeError(error);
    }
    for (final pending in _pending.values) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(error);
      }
    }
    _pending.clear();
    _activeRequestForLogs = null;
    _runtimeProbeFuture = null;
    _startedStartupProfileId = null;
    _process = null;
  }

  Future<Map<String, dynamic>> transcribe({
    required String wavPath,
    required String modelName,
    required String? language,
    required String device,
    required String computeType,
    required int batchSize,
    required bool noAlign,
    String? vadDevice,
    String? alignDevice,
    Map<String, dynamic>? asrOptions,
    Map<String, dynamic>? vadOptions,
    Map<String, dynamic>? segmentationOptions,
    void Function(int progress)? onProgress,
    void Function(String status, String? detail)? onStatus,
    void Function(String line)? onLog,
  }) {
    final Map<String, dynamic> params = <String, dynamic>{
      'wav_path': wavPath,
      'model': modelName,
      'language': language,
      'device': device,
      'asr_device': device,
      'compute_type': computeType,
      'batch_size': batchSize,
      'no_align': noAlign,
    };
    if (vadDevice != null && vadDevice.trim().isNotEmpty) {
      params['vad_device'] = vadDevice.trim();
    }
    if (alignDevice != null && alignDevice.trim().isNotEmpty) {
      params['align_device'] = alignDevice.trim();
    }
    if (asrOptions != null && asrOptions.isNotEmpty) {
      params['asr_options'] = asrOptions;
    }
    if (vadOptions != null && vadOptions.isNotEmpty) {
      params['vad_options'] = vadOptions;
    }
    if (segmentationOptions != null && segmentationOptions.isNotEmpty) {
      params['segmentation_options'] = segmentationOptions;
    }

    return _sendRequest(
      method: 'transcribe',
      params: params,
      onProgress: onProgress,
      onStatus: onStatus,
      onLog: onLog,
    );
  }

  Future<WhisperXRuntimeProbe> probeRuntime() {
    final Future<WhisperXRuntimeProbe>? cached = _runtimeProbeFuture;
    if (cached != null) {
      return cached;
    }

    final Future<WhisperXRuntimeProbe> future = _sendRequest(
      method: 'probe_runtime',
      params: const <String, dynamic>{},
    ).then(WhisperXRuntimeProbe.fromPayload);

    _runtimeProbeFuture = future;
    unawaited(
      future.then<void>(
        (_) {},
        onError: (_) {
          if (identical(_runtimeProbeFuture, future)) {
            _runtimeProbeFuture = null;
          }
        },
      ),
    );
    return future;
  }

  Future<Map<String, dynamic>> _sendRequest({
    required String method,
    required Map<String, dynamic> params,
    void Function(int progress)? onProgress,
    void Function(String status, String? detail)? onStatus,
    void Function(String line)? onLog,
  }) async {
    await ensureStarted();

    final Process? process = _process;
    if (process == null) {
      throw Exception('WhisperX sidecar is not running.');
    }

    final String id = (_requestSeq++).toString();
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = _PendingRequest(
      completer: completer,
      onProgress: onProgress,
      onStatus: onStatus,
      onLog: onLog,
    );
    _activeRequestForLogs = id;

    process.stdin.writeln(
      jsonEncode({'id': id, 'method': method, 'params': params}),
    );

    return completer.future;
  }

  Future<void> dispose() async {
    final Process? process = _process;
    if (process == null) {
      return;
    }

    try {
      process.stdin.writeln(
        jsonEncode({
          'id': 'shutdown',
          'method': 'shutdown',
          'params': <String, dynamic>{},
        }),
      );
      await process.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {
      process.kill();
    }

    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    _process = null;
    _readyCompleter = null;
    _pending.clear();
    _activeRequestForLogs = null;
    _runtimeProbeFuture = null;
    _startedStartupProfileId = null;
  }
}
