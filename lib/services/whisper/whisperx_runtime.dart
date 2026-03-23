import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/whisper_download_source.dart';

class WhisperXRuntimeInfo {
  final String pythonExecutable;
  final String workerScriptPath;
  final Map<String, String> environment;

  const WhisperXRuntimeInfo({
    required this.pythonExecutable,
    required this.workerScriptPath,
    required this.environment,
  });
}

class _PythonCommand {
  final String executable;
  final List<String> prefixArgs;

  const _PythonCommand({required this.executable, this.prefixArgs = const []});
}

class _ManagedRuntimeSpec {
  final String id;
  final Uri url;
  final String sha256Hex;
  final String archiveType;
  final String pythonRelativePath;

  const _ManagedRuntimeSpec({
    required this.id,
    required this.url,
    required this.sha256Hex,
    required this.archiveType,
    required this.pythonRelativePath,
  });
}

class _WhisperXDependencyProfile {
  final String id;
  final bool prefersCuda;
  final String? torchIndexUrl;

  const _WhisperXDependencyProfile({
    required this.id,
    required this.prefersCuda,
    this.torchIndexUrl,
  });
}

class _CudaVersion implements Comparable<_CudaVersion> {
  final int major;
  final int minor;

  const _CudaVersion(this.major, this.minor);

  static _CudaVersion? tryParse(String value) {
    final Match? match = RegExp(r'(\d+)\.(\d+)').firstMatch(value);
    if (match == null) {
      return null;
    }

    return _CudaVersion(int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  @override
  int compareTo(_CudaVersion other) {
    final int majorDiff = major.compareTo(other.major);
    if (majorDiff != 0) {
      return majorDiff;
    }
    return minor.compareTo(other.minor);
  }

  @override
  String toString() => '$major.$minor';
}

/// Ensures local Python runtime for WhisperX sidecar execution.
///
/// Runtime resolution order:
/// 1) Managed runtime package (download + verify + extract) if configured.
/// 2) System Python fallback (for development environments).
class WhisperXRuntime {
  static const String _runtimeDirName = 'whisperx_sidecar';
  static const String _workerAssetPath = 'assets/sidecar/whisperx_worker.py';
  static const String _workerFileName = 'whisperx_worker.py';
  static const String _manifestAssetPath =
      'assets/sidecar/runtime_manifest.json';
  static const String _runtimeVersion = '3';
  static const String _venvMarkerFile = '.runtime_ready_v3';
  static const String _managedMarkerFile = '.managed_runtime_v1';
  static const String _targetWhisperxVersion = '3.8.2';
  static const String _torchCpuIndexUrl =
      'https://download.pytorch.org/whl/cpu';

  WhisperXRuntime._();

  static final WhisperXRuntime instance = WhisperXRuntime._();

  WhisperXRuntimeInfo? _cachedInfo;
  String? _cachedRuntimeProfileId;
  WhisperDownloadSource _downloadSourceProfile = WhisperDownloadSource.global;

  WhisperDownloadSource get downloadSourceProfile => _downloadSourceProfile;

  set downloadSourceProfile(WhisperDownloadSource value) {
    if (_downloadSourceProfile == value) {
      return;
    }
    _downloadSourceProfile = value;
    _cachedInfo = null;
    _cachedRuntimeProfileId = null;
  }

  Future<String> resolveCurrentStartupProfileId() async {
    final _WhisperXDependencyProfile profile =
        await _resolveDependencyProfile();
    return _buildRuntimeProfileId(profile);
  }

  Future<WhisperXRuntimeInfo> ensureReady({
    void Function(int percent)? onProgress,
    void Function(int received, int total)? onDownloadProgress,
    void Function(String phase)? onStatus,
    void Function(String line)? onLog,
  }) async {
    onStatus?.call('checking_runtime');
    final _WhisperXDependencyProfile dependencyProfile =
        await _resolveDependencyProfile();
    final String runtimeProfileId = _buildRuntimeProfileId(dependencyProfile);

    if (_cachedInfo != null && _cachedRuntimeProfileId == runtimeProfileId) {
      onProgress?.call(100);
      return _cachedInfo!;
    }

    onProgress?.call(2);
    final Directory supportDir = await getApplicationSupportDirectory();
    final Directory runtimeDir = Directory(
      p.join(supportDir.path, _runtimeDirName),
    );
    await runtimeDir.create(recursive: true);

    onProgress?.call(6);
    final String workerPath = await _ensureWorkerScript(runtimeDir);

    onProgress?.call(10);
    final String basePythonExecutable = await _resolveBasePython(
      runtimeDir,
      onProgress: onProgress,
      onDownloadProgress: onDownloadProgress,
      onStatus: onStatus,
      onLog: onLog,
    );
    final Map<String, String> sidecarEnvironment =
        await _buildSidecarEnvironment(runtimeDir);

    onProgress?.call(62);
    final Directory venvDir = Directory(p.join(runtimeDir.path, 'venv'));
    onStatus?.call('creating_environment');
    await _ensureVenv(venvDir, basePythonExecutable, onLog: onLog);

    final String venvPythonPath = _resolveVenvPython(venvDir);
    if (!File(venvPythonPath).existsSync()) {
      throw Exception('Python venv is missing executable: $venvPythonPath');
    }

    onProgress?.call(72);
    final File marker = File(p.join(runtimeDir.path, _venvMarkerFile));
    if (!await _isWhisperxInstalled(venvPythonPath) ||
        !await _isDependencyMarkerValid(marker, dependencyProfile)) {
      await _installDependencies(
        venvPythonPath,
        dependencyProfile: dependencyProfile,
        onProgress: onProgress,
        onStatus: onStatus,
        onLog: onLog,
      );
      await marker.writeAsString(
        jsonEncode({
          'runtimeVersion': _runtimeVersion,
          'whisperxVersion': _targetWhisperxVersion,
          'dependencyProfileId': dependencyProfile.id,
          'prefersCuda': dependencyProfile.prefersCuda,
          'torchIndexUrl': dependencyProfile.torchIndexUrl,
          'createdAt': DateTime.now().toIso8601String(),
        }),
      );
    } else {
      onProgress?.call(94);
    }

    final info = WhisperXRuntimeInfo(
      pythonExecutable: venvPythonPath,
      workerScriptPath: workerPath,
      environment: sidecarEnvironment,
    );
    _cachedInfo = info;
    _cachedRuntimeProfileId = runtimeProfileId;
    onProgress?.call(100);
    return info;
  }

  String _buildRuntimeProfileId(_WhisperXDependencyProfile dependencyProfile) {
    return '${_downloadSourceProfile.id}:${dependencyProfile.id}';
  }

  Future<String> _ensureWorkerScript(Directory runtimeDir) async {
    final File scriptFile = File(p.join(runtimeDir.path, _workerFileName));
    final ByteData data = await rootBundle.load(_workerAssetPath);
    final String scriptContent = utf8.decode(data.buffer.asUint8List());

    if (!scriptFile.existsSync()) {
      await scriptFile.writeAsString(scriptContent);
      return scriptFile.path;
    }

    final String existing = await scriptFile.readAsString();
    if (existing != scriptContent) {
      await scriptFile.writeAsString(scriptContent);
    }
    return scriptFile.path;
  }

  Future<String> _resolveBasePython(
    Directory runtimeDir, {
    void Function(int percent)? onProgress,
    void Function(int received, int total)? onDownloadProgress,
    void Function(String phase)? onStatus,
    void Function(String line)? onLog,
  }) async {
    final _ManagedRuntimeSpec? managedSpec = await _loadManagedSpec();
    if (managedSpec != null) {
      final String managedPython = await _ensureManagedRuntime(
        runtimeDir,
        managedSpec,
        onProgress: onProgress,
        onDownloadProgress: onDownloadProgress,
        onStatus: onStatus,
        onLog: onLog,
      );
      if (File(managedPython).existsSync()) {
        return managedPython;
      }
    }

    final _PythonCommand systemPython = await _findSystemPython();
    return systemPython.executable;
  }

  Future<_ManagedRuntimeSpec?> _loadManagedSpec() async {
    final String raw = await rootBundle.loadString(_manifestAssetPath);
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final dynamic packagesRaw = decoded['packages'];
    if (packagesRaw is! Map<String, dynamic>) {
      return null;
    }

    final String platformKey = _currentPlatformKey();
    final dynamic specRaw = packagesRaw[platformKey];
    if (specRaw is! Map<String, dynamic>) {
      return null;
    }

    final String urlText = (specRaw['url'] as String? ?? '').trim();
    if (urlText.isEmpty) {
      return null;
    }

    final String sha256Hex = (specRaw['sha256'] as String? ?? '').trim();
    final String archiveType = (specRaw['archive_type'] as String? ?? 'zip')
        .trim()
        .toLowerCase();
    final String pythonRelativePath =
        (specRaw['python_relative_path'] as String? ?? '').trim();
    if (pythonRelativePath.isEmpty) {
      throw Exception(
        'Invalid runtime manifest for "$platformKey": '
        'python_relative_path is required.',
      );
    }

    final Uri? uri = Uri.tryParse(urlText);
    if (uri == null) {
      throw Exception('Invalid runtime URL in manifest: $urlText');
    }

    return _ManagedRuntimeSpec(
      id: platformKey,
      url: uri,
      sha256Hex: sha256Hex.toLowerCase(),
      archiveType: archiveType,
      pythonRelativePath: pythonRelativePath,
    );
  }

  String _currentPlatformKey() {
    final version = Platform.version.toLowerCase();
    final bool isArm64 =
        version.contains('arm64') || version.contains('aarch64');

    if (Platform.isMacOS) {
      return isArm64 ? 'macos-arm64' : 'macos-x64';
    }
    if (Platform.isWindows) {
      return 'windows-x64';
    }

    throw UnsupportedError(
      'Managed runtime is unsupported on ${Platform.operatingSystem}',
    );
  }

  Future<String> _ensureManagedRuntime(
    Directory runtimeDir,
    _ManagedRuntimeSpec spec, {
    void Function(int percent)? onProgress,
    void Function(int received, int total)? onDownloadProgress,
    void Function(String phase)? onStatus,
    void Function(String line)? onLog,
  }) async {
    final Directory managedDir = Directory(
      p.join(runtimeDir.path, 'managed_python_${spec.id}'),
    );
    final File marker = File(p.join(managedDir.path, _managedMarkerFile));
    final String pythonPath = p.join(managedDir.path, spec.pythonRelativePath);

    if (managedDir.existsSync() &&
        File(pythonPath).existsSync() &&
        await _isManagedRuntimeValid(marker, spec)) {
      if (await _canExecutePython(pythonPath)) {
        onLog?.call('Using cached managed Python runtime: $pythonPath');
        onProgress?.call(55);
        return pythonPath;
      }
      await managedDir.delete(recursive: true);
    }

    final Directory tempDir = Directory(
      p.join(runtimeDir.path, 'tmp_${DateTime.now().microsecondsSinceEpoch}'),
    );
    await tempDir.create(recursive: true);

    try {
      onProgress?.call(14);
      onStatus?.call('downloading_runtime');
      final String archiveExt = spec.archiveType == 'tar.gz' ? 'tar.gz' : 'zip';
      final File archiveFile = File(
        p.join(tempDir.path, 'runtime.$archiveExt'),
      );

      await _downloadManagedRuntime(
        spec.url,
        archiveFile,
        onLog: onLog,
        onProgress: (received, total) {
          onDownloadProgress?.call(received, total);
          if (total > 0) {
            final int mapped = 14 + ((received * 20) ~/ total);
            onProgress?.call(mapped.clamp(14, 34));
          }
        },
      );

      onProgress?.call(36);
      if (spec.sha256Hex.isNotEmpty) {
        final String hash = await _sha256OfFile(archiveFile);
        if (hash != spec.sha256Hex) {
          throw Exception(
            'Managed runtime checksum mismatch.\n'
            'Expected: ${spec.sha256Hex}\nActual:   $hash',
          );
        }
      }

      onProgress?.call(40);
      onStatus?.call('extracting_runtime');
      final Directory stageDir = Directory(p.join(tempDir.path, 'stage'));
      await stageDir.create(recursive: true);
      await _extractArchive(archiveFile, stageDir, spec.archiveType);

      onProgress?.call(50);
      if (managedDir.existsSync()) {
        await managedDir.delete(recursive: true);
      }
      await stageDir.rename(managedDir.path);

      if (!File(pythonPath).existsSync()) {
        throw Exception(
          'Managed runtime installed but python executable is missing: $pythonPath',
        );
      }
      if (!await _canExecutePython(pythonPath)) {
        throw Exception(
          'Managed runtime installed but python is not executable: $pythonPath',
        );
      }

      await marker.writeAsString(
        jsonEncode({
          'id': spec.id,
          'url': spec.url.toString(),
          'sha256': spec.sha256Hex,
          'archive_type': spec.archiveType,
          'python_relative_path': spec.pythonRelativePath,
          'installedAt': DateTime.now().toIso8601String(),
        }),
      );

      onProgress?.call(55);
      return pythonPath;
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<bool> _isManagedRuntimeValid(
    File marker,
    _ManagedRuntimeSpec spec,
  ) async {
    if (!await marker.exists()) {
      return false;
    }

    try {
      final dynamic decoded = jsonDecode(await marker.readAsString());
      if (decoded is! Map<String, dynamic>) return false;
      return (decoded['id'] as String? ?? '') == spec.id &&
          (decoded['url'] as String? ?? '') == spec.url.toString() &&
          (decoded['sha256'] as String? ?? '').toLowerCase() ==
              spec.sha256Hex &&
          (decoded['archive_type'] as String? ?? '').toLowerCase() ==
              spec.archiveType.toLowerCase() &&
          (decoded['python_relative_path'] as String? ?? '') ==
              spec.pythonRelativePath;
    } catch (_) {
      return false;
    }
  }

  Future<_WhisperXDependencyProfile> _resolveDependencyProfile() async {
    if (!Platform.isWindows) {
      return const _WhisperXDependencyProfile(
        id: 'default',
        prefersCuda: false,
      );
    }

    final _CudaVersion? cudaVersion = await _detectWindowsCudaVersion();
    final String? torchChannel = _selectWindowsTorchChannel(cudaVersion);
    if (torchChannel == null) {
      return const _WhisperXDependencyProfile(
        id: 'windows-cpu',
        prefersCuda: false,
        torchIndexUrl: _torchCpuIndexUrl,
      );
    }

    return _WhisperXDependencyProfile(
      id: 'windows-$torchChannel',
      prefersCuda: true,
      torchIndexUrl: 'https://download.pytorch.org/whl/$torchChannel',
    );
  }

  Future<_CudaVersion?> _detectWindowsCudaVersion() async {
    if (!Platform.isWindows) {
      return null;
    }

    final String? systemRoot = Platform.environment['SystemRoot'];
    final Set<String> candidates = <String>{
      'nvidia-smi',
      if ((systemRoot ?? '').isNotEmpty)
        p.join(systemRoot!, 'System32', 'nvidia-smi.exe'),
    };

    for (final String executable in candidates) {
      try {
        final ProcessResult result = await Process.run(
          executable,
          const <String>[],
        );
        if (result.exitCode != 0) {
          continue;
        }

        final String output = '${result.stdout}\n${result.stderr}';
        final Match? match = RegExp(
          r'CUDA Version:\s*([0-9]+\.[0-9]+)',
          caseSensitive: false,
        ).firstMatch(output);
        if (match == null) {
          continue;
        }

        final _CudaVersion? parsed = _CudaVersion.tryParse(match.group(1)!);
        if (parsed != null) {
          return parsed;
        }
      } catch (_) {
        continue;
      }
    }

    return _detectWindowsCudaVersionFromEnvironment();
  }

  _CudaVersion? _detectWindowsCudaVersionFromEnvironment() {
    _CudaVersion? best;

    for (final MapEntry<String, String> entry in Platform.environment.entries) {
      final Match? match = RegExp(
        r'^CUDA_PATH_V(\d+)_(\d+)$',
        caseSensitive: false,
      ).firstMatch(entry.key);
      if (match == null) {
        continue;
      }

      final _CudaVersion parsed = _CudaVersion(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
      );
      if (best == null || parsed.compareTo(best) > 0) {
        best = parsed;
      }
    }

    if (best != null) {
      return best;
    }

    final String? cudaPath = Platform.environment['CUDA_PATH'];
    if (cudaPath == null || cudaPath.trim().isEmpty) {
      return null;
    }

    return _CudaVersion.tryParse(cudaPath);
  }

  String? _selectWindowsTorchChannel(_CudaVersion? cudaVersion) {
    if (cudaVersion == null) {
      return null;
    }

    if (cudaVersion.compareTo(const _CudaVersion(12, 6)) >= 0) {
      return 'cu126';
    }
    if (cudaVersion.compareTo(const _CudaVersion(12, 4)) >= 0) {
      return 'cu124';
    }
    if (cudaVersion.compareTo(const _CudaVersion(12, 1)) >= 0) {
      return 'cu121';
    }
    if (cudaVersion.compareTo(const _CudaVersion(11, 8)) >= 0) {
      return 'cu118';
    }

    return null;
  }

  Future<bool> _isDependencyMarkerValid(
    File marker,
    _WhisperXDependencyProfile dependencyProfile,
  ) async {
    if (!await marker.exists()) {
      return false;
    }

    try {
      final dynamic decoded = jsonDecode(await marker.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      return (decoded['runtimeVersion'] as String? ?? '') == _runtimeVersion &&
          (decoded['whisperxVersion'] as String? ?? '') ==
              _targetWhisperxVersion &&
          (decoded['dependencyProfileId'] as String? ?? '') ==
              dependencyProfile.id &&
          (decoded['torchIndexUrl'] as String?) ==
              dependencyProfile.torchIndexUrl;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> _buildSidecarEnvironment(
    Directory runtimeDir,
  ) async {
    final Directory modelCacheDir = Directory(
      p.join(runtimeDir.path, 'model_cache'),
    );
    final Directory asrModelDir = Directory(p.join(modelCacheDir.path, 'asr'));
    final Directory alignModelDir = Directory(
      p.join(modelCacheDir.path, 'align'),
    );
    final Directory huggingFaceDir = Directory(
      p.join(modelCacheDir.path, 'huggingface'),
    );
    final Directory huggingFaceHubDir = Directory(
      p.join(huggingFaceDir.path, 'hub'),
    );
    final Directory torchDir = Directory(p.join(modelCacheDir.path, 'torch'));
    final Directory xdgDir = Directory(p.join(modelCacheDir.path, 'xdg'));

    for (final Directory directory in <Directory>[
      modelCacheDir,
      asrModelDir,
      alignModelDir,
      huggingFaceDir,
      huggingFaceHubDir,
      torchDir,
      xdgDir,
    ]) {
      await directory.create(recursive: true);
    }

    final Map<String, String> environment = <String, String>{
      'WHISPERX_ASR_MODEL_DIR': asrModelDir.path,
      'WHISPERX_ALIGN_MODEL_DIR': alignModelDir.path,
      'HF_HOME': huggingFaceDir.path,
      'HF_HUB_CACHE': huggingFaceHubDir.path,
      'TORCH_HOME': torchDir.path,
      'XDG_CACHE_HOME': xdgDir.path,
    };

    final String? huggingFaceEndpoint = switch (_downloadSourceProfile) {
      WhisperDownloadSource.global => null,
      WhisperDownloadSource.mainlandChina => 'https://hf-mirror.com',
    };
    if (huggingFaceEndpoint != null) {
      environment['HF_ENDPOINT'] = huggingFaceEndpoint;
    }
    return environment;
  }

  Future<void> _downloadManagedRuntime(
    Uri officialUrl,
    File output, {
    void Function(String line)? onLog,
    void Function(int received, int total)? onProgress,
  }) async {
    final List<Uri> candidates = _buildManagedRuntimeCandidates(officialUrl);
    final List<String> failures = <String>[];

    for (final Uri candidate in candidates) {
      if (output.existsSync()) {
        await output.delete();
      }

      try {
        onLog?.call('Downloading managed runtime from $candidate');
        await _downloadFile(candidate, output, onProgress: onProgress);
        return;
      } catch (error) {
        onLog?.call('Managed runtime download failed from $candidate: $error');
        failures.add('$candidate -> $error');
      }
    }

    throw Exception(
      'Failed to download managed runtime from all configured sources.\n'
      '${failures.join('\n')}',
    );
  }

  List<Uri> _buildManagedRuntimeCandidates(Uri officialUrl) {
    if (_downloadSourceProfile != WhisperDownloadSource.mainlandChina) {
      return <Uri>[officialUrl];
    }

    final Set<String> seen = <String>{};
    final List<Uri> urls = <Uri>[];
    void add(Uri uri) {
      if (seen.add(uri.toString())) {
        urls.add(uri);
      }
    }

    final List<Uri> mirrors = _githubReleaseMirrorCandidates(officialUrl);
    for (final Uri mirror in mirrors) {
      add(mirror);
    }
    add(officialUrl);
    return urls;
  }

  List<Uri> _githubReleaseMirrorCandidates(Uri officialUrl) {
    if (officialUrl.host != 'github.com') {
      return const <Uri>[];
    }

    final List<String> segments = officialUrl.pathSegments;
    if (segments.length < 6 ||
        segments[2] != 'releases' ||
        segments[3] != 'download') {
      return const <Uri>[];
    }

    final String owner = segments[0];
    final String repo = segments[1];
    final String tag = segments[4];
    final List<String> assetSegments = segments.sublist(5);

    Uri buildMirror(String host) {
      return Uri(
        scheme: 'https',
        host: host,
        pathSegments: <String>[
          'github-release',
          owner,
          repo,
          tag,
          ...assetSegments,
        ],
      );
    }

    return <Uri>[
      buildMirror('mirror.nju.edu.cn'),
      buildMirror('mirrors.ustc.edu.cn'),
    ];
  }

  Future<void> _downloadFile(
    Uri url,
    File output, {
    void Function(int received, int total)? onProgress,
  }) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(url);
      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode} ($url)');
      }

      final int total = response.contentLength;
      int received = 0;
      final IOSink sink = output.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.close();
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _sha256OfFile(File file) async {
    final Digest digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase();
  }

  Future<void> _extractArchive(
    File archiveFile,
    Directory destination,
    String archiveType,
  ) async {
    final String type = archiveType.toLowerCase();
    if (type != 'zip' && type != 'tar.gz') {
      throw Exception('Unsupported archive_type: $archiveType');
    }
    await extractFileToDisk(archiveFile.path, destination.path);
  }

  Future<bool> _canExecutePython(String pythonPath) async {
    try {
      final result = await Process.run(pythonPath, ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<_PythonCommand> _findSystemPython() async {
    final List<_PythonCommand> candidates = Platform.isWindows
        ? const [
            _PythonCommand(executable: 'py', prefixArgs: ['-3']),
            _PythonCommand(executable: 'python'),
            _PythonCommand(executable: 'python3'),
          ]
        : const [
            _PythonCommand(executable: 'python3'),
            _PythonCommand(executable: 'python'),
          ];

    for (final candidate in candidates) {
      final result = await Process.run(candidate.executable, [
        ...candidate.prefixArgs,
        '--version',
      ]);
      if (result.exitCode == 0) {
        return candidate;
      }
    }

    throw Exception(
      'No managed runtime configured and no system Python found.\n'
      'Please configure assets/sidecar/runtime_manifest.json for '
      '${_currentPlatformKey()}, or install Python 3.10+ into PATH.',
    );
  }

  Future<void> _ensureVenv(
    Directory venvDir,
    String basePythonExecutable, {
    void Function(String line)? onLog,
  }) async {
    if (venvDir.existsSync()) {
      onLog?.call('Using cached Python environment: ${venvDir.path}');
      return;
    }
    await _runOrThrow(
      basePythonExecutable,
      ['-m', 'venv', venvDir.path],
      errorPrefix: 'Failed to create Python venv.',
      onLog: onLog,
    );
  }

  String _resolveVenvPython(Directory venvDir) {
    if (Platform.isWindows) {
      return p.join(venvDir.path, 'Scripts', 'python.exe');
    }

    final String python3 = p.join(venvDir.path, 'bin', 'python3');
    if (File(python3).existsSync()) {
      return python3;
    }
    return p.join(venvDir.path, 'bin', 'python');
  }

  Future<bool> _isWhisperxInstalled(String pythonExecutable) async {
    final result = await Process.run(pythonExecutable, [
      '-c',
      'from importlib import metadata; import whisperx, numpy; '
          'print(metadata.version("whisperx"))',
    ]);
    if (result.exitCode != 0) {
      return false;
    }

    final String version = (result.stdout as String).trim();
    return version == _targetWhisperxVersion;
  }

  Future<void> _installDependencies(
    String pythonExecutable, {
    required _WhisperXDependencyProfile dependencyProfile,
    void Function(int percent)? onProgress,
    void Function(String phase)? onStatus,
    void Function(String line)? onLog,
  }) async {
    onStatus?.call('installing_dependencies');
    onProgress?.call(78);
    final Map<String, String> pipEnvironment = _buildPipEnvironment();
    final List<String> pipIndexArgs = _buildPipIndexArgs();
    await _runOrThrow(
      pythonExecutable,
      ['-m', 'pip', 'install', '--upgrade', 'pip', ...pipIndexArgs],
      errorPrefix: 'Failed to upgrade pip for WhisperX runtime.',
      environment: pipEnvironment,
      onLog: onLog,
    );

    onProgress?.call(84);
    onLog?.call('Installing WhisperX and runtime dependencies...');
    await _runOrThrow(
      pythonExecutable,
      [
        '-m',
        'pip',
        'install',
        ...pipIndexArgs,
        'whisperx==$_targetWhisperxVersion',
        'numpy',
      ],
      errorPrefix: 'Failed to install WhisperX runtime dependencies.',
      environment: pipEnvironment,
      onLog: onLog,
    );

    if (Platform.isWindows && dependencyProfile.torchIndexUrl != null) {
      // whisperx resolves torch from the default index, which can replace a
      // previously installed CUDA wheel with the CPU build on Windows.
      // Reinstall the desired torch channel last so probe_runtime sees the
      // actual GPU-capable runtime.
      onProgress?.call(90);
      await _installWindowsTorchRuntime(
        pythonExecutable,
        dependencyProfile: dependencyProfile,
        environment: pipEnvironment,
        onLog: onLog,
      );
    }

    onProgress?.call(94);
  }

  Future<void> _installWindowsTorchRuntime(
    String pythonExecutable, {
    required _WhisperXDependencyProfile dependencyProfile,
    required Map<String, String> environment,
    void Function(String line)? onLog,
  }) async {
    await _runBestEffort(pythonExecutable, [
      '-m',
      'pip',
      'uninstall',
      '-y',
      'torch',
      'torchaudio',
      'torchvision',
    ], environment: environment);

    final String torchIndexUrl = _resolveTorchIndexUrl(
      dependencyProfile.torchIndexUrl!,
    );
    final List<String> torchInstallSourceArgs = _buildTorchInstallSourceArgs(
      torchIndexUrl,
    );
    onLog?.call('Installing PyTorch runtime from $torchIndexUrl');

    await _runOrThrow(
      pythonExecutable,
      [
        '-m',
        'pip',
        'install',
        '--upgrade',
        'torch',
        'torchaudio',
        ...torchInstallSourceArgs,
      ],
      errorPrefix: dependencyProfile.prefersCuda
          ? 'Failed to install CUDA-enabled PyTorch runtime for WhisperX.'
          : 'Failed to install CPU PyTorch runtime for WhisperX.',
      environment: environment,
      onLog: onLog,
    );
  }

  Map<String, String> _buildPipEnvironment() {
    return <String, String>{
      'PIP_DISABLE_PIP_VERSION_CHECK': '1',
      'PIP_PROGRESS_BAR': 'off',
      'PYTHONUNBUFFERED': '1',
    };
  }

  List<String> _buildPipIndexArgs() {
    return switch (_downloadSourceProfile) {
      WhisperDownloadSource.global => const <String>[],
      WhisperDownloadSource.mainlandChina => const <String>[
        '--index-url',
        'https://mirrors.ustc.edu.cn/pypi/simple',
      ],
    };
  }

  String _resolveTorchIndexUrl(String indexUrl) {
    if (_downloadSourceProfile != WhisperDownloadSource.mainlandChina) {
      return indexUrl;
    }
    return indexUrl.replaceFirst(
      'https://download.pytorch.org/whl',
      'https://mirrors.aliyun.com/pytorch-wheels',
    );
  }

  List<String> _buildTorchInstallSourceArgs(String torchIndexUrl) {
    if (_downloadSourceProfile != WhisperDownloadSource.mainlandChina) {
      return <String>['--index-url', torchIndexUrl];
    }

    // Aliyun mirrors the wheel files, but pip may fail to resolve versions when
    // treating it as a PEP 503 index. Using find-links works reliably with the
    // mirrored wheel listing for torch/torchaudio on Windows.
    return <String>['--no-index', '--find-links', '$torchIndexUrl/'];
  }

  Future<void> _runBestEffort(
    String executable,
    List<String> args, {
    Map<String, String>? environment,
  }) async {
    try {
      await Process.run(executable, args, environment: environment);
    } catch (_) {
      return;
    }
  }

  Future<void> _runOrThrow(
    String executable,
    List<String> args, {
    required String errorPrefix,
    Map<String, String>? environment,
    void Function(String line)? onLog,
  }) async {
    onLog?.call('Running: $executable ${args.join(' ')}');
    final Process process = await Process.start(
      executable,
      args,
      environment: environment,
      runInShell: false,
    );
    final StringBuffer stdoutBuffer = StringBuffer();
    final StringBuffer stderrBuffer = StringBuffer();
    final Future<void> stdoutDone = _pumpProcessStream(
      process.stdout,
      stdoutBuffer,
      onLog: onLog,
    );
    final Future<void> stderrDone = _pumpProcessStream(
      process.stderr,
      stderrBuffer,
      onLog: onLog,
    );
    final int exitCode = await process.exitCode;
    await Future.wait(<Future<void>>[stdoutDone, stderrDone]);
    if (exitCode == 0) {
      return;
    }

    throw Exception(
      '$errorPrefix\nCommand: $executable ${args.join(' ')}\n'
      'STDOUT:\n${stdoutBuffer.toString()}\nSTDERR:\n${stderrBuffer.toString()}',
    );
  }

  Future<void> _pumpProcessStream(
    Stream<List<int>> stream,
    StringBuffer output, {
    void Function(String line)? onLog,
  }) async {
    await for (final String line
        in stream.transform(utf8.decoder).transform(const LineSplitter())) {
      final String trimmed = line.trimRight();
      output.writeln(trimmed);
      if (trimmed.isNotEmpty) {
        onLog?.call(trimmed);
      }
    }
  }
}
