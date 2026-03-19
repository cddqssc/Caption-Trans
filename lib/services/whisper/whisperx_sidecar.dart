import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'whisperx_runtime.dart';

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

  Future<void> ensureStarted({
    void Function(int percent)? onBootstrapProgress,
    void Function(int received, int total)? onRuntimeDownloadProgress,
  }) async {
    if (_process != null) {
      return;
    }

    if (_startFuture != null) {
      await _startFuture;
      return;
    }

    _startFuture = _doStart(
      onBootstrapProgress: onBootstrapProgress,
      onRuntimeDownloadProgress: onRuntimeDownloadProgress,
    );
    try {
      await _startFuture;
    } finally {
      _startFuture = null;
    }
  }

  Future<void> _doStart({
    void Function(int percent)? onBootstrapProgress,
    void Function(int received, int total)? onRuntimeDownloadProgress,
  }) async {
    final WhisperXRuntimeInfo info = await WhisperXRuntime.instance.ensureReady(
      onProgress: onBootstrapProgress,
      onDownloadProgress: onRuntimeDownloadProgress,
    );

    _readyCompleter = Completer<void>();
    final process = await Process.start(
      info.pythonExecutable,
      [info.workerScriptPath],
      workingDirectory: p.dirname(info.workerScriptPath),
      runInShell: false,
    );
    _process = process;

    _stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleStdoutLine);

    _stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          debugPrint('[WhisperX][stderr] $line');
          final String? id = _activeRequestForLogs;
          if (id == null) return;
          final _PendingRequest? pending = _pending[id];
          pending?.onLog?.call(line);
        });

    process.exitCode.then((code) {
      final Exception error = Exception(
        'WhisperX sidecar exited unexpectedly: $code',
      );
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
      _process = null;
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

  Future<Map<String, dynamic>> transcribe({
    required String wavPath,
    required String modelName,
    required String? language,
    required String device,
    required String computeType,
    required int batchSize,
    required bool noAlign,
    void Function(int progress)? onProgress,
    void Function(String status, String? detail)? onStatus,
    void Function(String line)? onLog,
  }) {
    return _sendRequest(
      method: 'transcribe',
      params: {
        'wav_path': wavPath,
        'model': modelName,
        'language': language,
        'device': device,
        'compute_type': computeType,
        'batch_size': batchSize,
        'no_align': noAlign,
      },
      onProgress: onProgress,
      onStatus: onStatus,
      onLog: onLog,
    );
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
  }
}
