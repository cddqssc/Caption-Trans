import 'package:flutter/material.dart';
import '../../blocs/transcription/transcription_state.dart';
import '../../core/constants.dart';
import '../../models/whisper_runtime_info.dart';
import 'package:caption_trans/l10n/app_localizations.dart';

/// Panel for controlling Whisper transcription.
class TranscriptionPanel extends StatelessWidget {
  final TranscriptionState state;
  final String selectedModel;
  final String selectedSourceLanguage;
  final ValueChanged<String> onModelChanged;
  final ValueChanged<String> onSourceLanguageChanged;
  final VoidCallback onStartTranscription;

  const TranscriptionPanel({
    super.key,
    required this.state,
    required this.selectedModel,
    required this.selectedSourceLanguage,
    required this.onModelChanged,
    required this.onSourceLanguageChanged,
    required this.onStartTranscription,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final WhisperRuntimeInfo? runtimeInfo = _runtimeInfo;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.whisperModel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedModel,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: AppConstants.whisperModels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: _buildModelMenuItem(context, e.value, l10n),
                          ),
                        )
                        .toList(),
                    selectedItemBuilder: (context) {
                      return AppConstants.whisperModels.entries.map((e) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            e.key,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList();
                    },
                    onChanged: _isProcessing
                        ? null
                        : (v) {
                            if (v != null) onModelChanged(v);
                          },
                  ),
                ),
                const SizedBox(width: 16),
                _buildStartButton(context, l10n),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              l10n.sourceVideoLanguage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedSourceLanguage,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: AppConstants.supportedLanguages.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(
                        '${e.value} (${e.key})',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _isProcessing
                  ? null
                  : (v) {
                      if (v != null) onSourceLanguageChanged(v);
                    },
            ),
            const SizedBox(height: 6),
            Text(
              l10n.sourceVideoLanguageHint,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            if (_isProcessing ||
                state is TranscriptionComplete ||
                state is TranscriptionError)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusWidget(context, l10n),
                    if (runtimeInfo != null) ...[
                      const SizedBox(height: 12),
                      _buildRuntimeInfoCard(context, runtimeInfo),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool get _isProcessing =>
      state is RuntimePreparing ||
      state is AudioTranscoding ||
      state is Transcribing;

  bool get _canStart =>
      state is VideoSelected ||
      state is TranscriptionError ||
      state is TranscriptionComplete;

  WhisperRuntimeInfo? get _runtimeInfo {
    final TranscriptionState currentState = state;
    if (currentState is RuntimePreparing) return currentState.runtimeInfo;
    if (currentState is AudioTranscoding) return currentState.runtimeInfo;
    if (currentState is Transcribing) return currentState.runtimeInfo;
    if (currentState is TranscriptionComplete) return currentState.runtimeInfo;
    if (currentState is TranscriptionError) return currentState.runtimeInfo;
    return null;
  }

  Widget _buildStartButton(BuildContext context, AppLocalizations l10n) {
    if (_isProcessing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return FilledButton(
      onPressed: _canStart ? onStartTranscription : null,
      child: Text(l10n.extract),
    );
  }

  Widget _buildStatusWidget(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    if (state is RuntimePreparing) {
      final s = state as RuntimePreparing;
      final String label = _runtimePreparingLabel(l10n, s.phase);
      if (s.progress != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressRow(
              context,
              icon: Icons.download_rounded,
              label: label,
              progress: s.progress,
              color: Colors.blue,
            ),
            if (s.logLines.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildLogPanel(context, s.logLines),
            ],
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBusyRow(
            context,
            icon: Icons.settings_suggest_rounded,
            label: label,
            color: Colors.blue,
          ),
          if (s.logLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildLogPanel(context, s.logLines),
          ],
        ],
      );
    }

    if (state is AudioTranscoding) {
      return _buildStatusRow(
        context,
        icon: Icons.audio_file_rounded,
        label: l10n.transcodingAudio,
        color: Colors.orange,
      );
    }

    if (state is Transcribing) {
      final s = state as Transcribing;
      final String base = switch (s.phase) {
        TranscribingPhase.loadingAudio => l10n.transcriptionLoadingAudio,
        TranscribingPhase.preparingModel => l10n.transcriptionPreparingModel,
        TranscribingPhase.transcribing => l10n.transcriptionRunning,
        TranscribingPhase.aligning => l10n.transcriptionAligning,
        TranscribingPhase.finalizing => l10n.transcriptionFinalizing,
      };
      return _buildStatusWithLogs(
        context,
        icon: Icons.mic_rounded,
        label: base,
        logLines: s.logLines,
        color: Colors.purple,
      );
    }

    if (state is TranscriptionComplete) {
      final s = state as TranscriptionComplete;
      return Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Colors.greenAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.segmentsExtracted(s.result.segments.length, s.result.language),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.greenAccent,
            ),
          ),
        ],
      );
    }

    if (state is TranscriptionError) {
      final s = state as TranscriptionError;
      return _buildErrorDetails(
        context,
        message: s.message,
        logLines: s.logLines,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildProgressRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required double? progress,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildBusyRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusWithLogs(
    BuildContext context, {
    required IconData icon,
    required String label,
    required List<String> logLines,
    required Color color,
  }) {
    final List<String> visibleLogLines = logLines.length <= 6
        ? logLines
        : logLines.sublist(logLines.length - 6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusRow(context, icon: icon, label: label, color: color),
        if (visibleLogLines.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildLogPanel(context, visibleLogLines),
        ],
      ],
    );
  }

  Widget _buildLogPanel(BuildContext context, List<String> logLines) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 132),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        child: Text(
          logLines.join('\n'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorDetails(
    BuildContext context, {
    required String message,
    required List<String> logLines,
  }) {
    final ThemeData theme = Theme.of(context);
    final String combined = logLines.isEmpty
        ? message
        : '$message\n\nRecent logs:\n${logLines.join('\n')}';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.24)),
      ),
      child: SingleChildScrollView(
        child: Text(
          combined,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.redAccent,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _buildRuntimeInfoCard(
    BuildContext context,
    WhisperRuntimeInfo runtimeInfo,
  ) {
    final bool usingGpu = runtimeInfo.usingGpu;
    final Color accent = usingGpu ? Colors.greenAccent : Colors.orangeAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                usingGpu ? Icons.memory_rounded : Icons.developer_board_rounded,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  usingGpu ? 'GPU acceleration active' : 'CPU transcription',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRuntimeChip(runtimeInfo.modeLabel, accent),
              if (runtimeInfo.deviceName != null &&
                  runtimeInfo.deviceName!.trim().isNotEmpty)
                _buildRuntimeChip(runtimeInfo.deviceName!, Colors.white70),
              _buildRuntimeChip(
                'compute ${runtimeInfo.computeType}',
                Colors.white70,
              ),
              _buildRuntimeChip(
                'batch ${runtimeInfo.batchSize}',
                Colors.white70,
              ),
              if (runtimeInfo.physicalCpuCount != null ||
                  runtimeInfo.logicalCpuCount != null)
                _buildRuntimeChip(
                  _buildCpuCountLabel(runtimeInfo),
                  Colors.white70,
                ),
              if (runtimeInfo.recommendedCpuThreads != null)
                _buildRuntimeChip(
                  'threads ${runtimeInfo.recommendedCpuThreads}',
                  Colors.white70,
                ),
              if (runtimeInfo.torchCudaVersion != null &&
                  runtimeInfo.torchCudaVersion!.trim().isNotEmpty)
                _buildRuntimeChip(
                  'torch CUDA ${runtimeInfo.torchCudaVersion!}',
                  Colors.white70,
                ),
            ],
          ),
          if (runtimeInfo.note != null &&
              runtimeInfo.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              runtimeInfo.note!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ],
          if (!usingGpu && runtimeInfo.cudaAvailable) ...[
            const SizedBox(height: 8),
            Text(
              'CUDA is available, but this run is using CPU fallback.',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.orangeAccent),
            ),
          ],
        ],
      ),
    );
  }

  String _buildCpuCountLabel(WhisperRuntimeInfo runtimeInfo) {
    final int? physical = runtimeInfo.physicalCpuCount;
    final int? logical = runtimeInfo.logicalCpuCount;
    if (physical != null && logical != null) {
      return 'cpu $physical phys / $logical log';
    }
    if (physical != null) {
      return 'cpu $physical phys';
    }
    return 'cpu ${logical!} log';
  }

  Widget _buildRuntimeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _runtimePreparingLabel(
    AppLocalizations l10n,
    RuntimePreparingPhase phase,
  ) {
    switch (phase) {
      case RuntimePreparingPhase.checkingRuntime:
        return l10n.runtimeChecking;
      case RuntimePreparingPhase.downloadingRuntime:
        return l10n.runtimeDownloading;
      case RuntimePreparingPhase.extractingRuntime:
        return l10n.runtimeExtracting;
      case RuntimePreparingPhase.creatingEnvironment:
        return l10n.runtimeCreatingEnvironment;
      case RuntimePreparingPhase.installingDependencies:
        return l10n.runtimeInstallingDependencies;
      case RuntimePreparingPhase.startingSidecar:
        return l10n.runtimeStartingSidecar;
    }
  }

  Widget _buildModelMenuItem(
    BuildContext context,
    WhisperModelInfo info,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              info.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          _buildModelSpecColumn(l10n.diskUsage, info.diskUsage),
          _buildModelSpecColumn(l10n.memoryUsage, info.memoryUsage),
          _buildModelSpecColumn(l10n.transcriptionQuality, info.quality(l10n)),
        ],
      ),
    );
  }

  Widget _buildModelSpecColumn(String label, String value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
