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
      state is ModelPreparing ||
      state is AudioTranscoding ||
      state is Transcribing;

  bool get _canStart =>
      state is VideoSelected ||
      state is TranscriptionError ||
      state is TranscriptionComplete;

  WhisperRuntimeInfo? get _runtimeInfo {
    final TranscriptionState currentState = state;
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
    if (state is ModelPreparing) {
      final s = state as ModelPreparing;
      final String label = _modelPreparingLabel(l10n, s.phase);
      if (s.progress != null) {
        return _buildProgressRow(
          context,
          icon: Icons.download_rounded,
          label: label,
          progress: s.progress,
          color: Colors.blue,
        );
      }
      return _buildBusyRow(
        context,
        icon: Icons.settings_suggest_rounded,
        label: label,
        color: Colors.blue,
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
        TranscribingPhase.transcribing => l10n.transcriptionRunning,
        TranscribingPhase.finalizing => l10n.transcriptionFinalizing,
      };
      final String detail = (s.statusDetail ?? '').trim();
      final String label = detail.isEmpty ? base : '$base\n$detail';
      return _buildStatusRow(
        context,
        icon: Icons.mic_rounded,
        label: label,
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.greenAccent,
            ),
          ),
        ],
      );
    }

    if (state is TranscriptionError) {
      final s = state as TranscriptionError;
      return Row(
        children: [
          const Icon(Icons.error_rounded, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.redAccent,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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

  Widget _buildRuntimeInfoCard(
    BuildContext context,
    WhisperRuntimeInfo runtimeInfo,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.developer_board_rounded,
                size: 16,
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  runtimeInfo.modeLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.blueAccent,
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
              _buildRuntimeChip(
                'threads ${runtimeInfo.numThreads}',
                Colors.white70,
              ),
              if (runtimeInfo.deviceName != null &&
                  runtimeInfo.deviceName!.trim().isNotEmpty)
                _buildRuntimeChip(runtimeInfo.deviceName!, Colors.white70),
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
        ],
      ),
    );
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

  String _modelPreparingLabel(
    AppLocalizations l10n,
    ModelPreparingPhase phase,
  ) {
    switch (phase) {
      case ModelPreparingPhase.checkingModel:
        return l10n.runtimeChecking;
      case ModelPreparingPhase.downloadingModel:
        return l10n.runtimeDownloading;
      case ModelPreparingPhase.extractingModel:
        return l10n.runtimeExtracting;
      case ModelPreparingPhase.loadingModel:
        return l10n.transcriptionPreparingModel;
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
