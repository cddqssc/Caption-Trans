import 'package:flutter/material.dart';
import '../../blocs/transcription/transcription_state.dart';
import '../../core/constants.dart';
import 'package:caption_trans/l10n/app_localizations.dart';

/// Panel for controlling Whisper transcription.
class TranscriptionPanel extends StatelessWidget {
  final TranscriptionState state;
  final String selectedModel;
  final ValueChanged<String> onModelChanged;
  final VoidCallback onStartTranscription;

  const TranscriptionPanel({
    super.key,
    required this.state,
    required this.selectedModel,
    required this.onModelChanged,
    required this.onStartTranscription,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

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
            if (_isProcessing ||
                state is TranscriptionComplete ||
                state is TranscriptionError)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _buildStatusWidget(context, l10n),
              ),
          ],
        ),
      ),
    );
  }

  bool get _isProcessing =>
      state is ModelDownloading ||
      state is AudioExtracting ||
      state is Transcribing;

  bool get _canStart =>
      state is VideoSelected ||
      state is TranscriptionError ||
      state is TranscriptionComplete;

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

    if (state is ModelDownloading) {
      final s = state as ModelDownloading;
      return _buildProgressRow(
        context,
        icon: Icons.download_rounded,
        label: l10n.downloadingModel(s.modelName),
        progress: s.progress >= 0 ? s.progress : null,
        color: Colors.blue,
      );
    }

    if (state is AudioExtracting) {
      return _buildProgressRow(
        context,
        icon: Icons.audio_file_rounded,
        label: l10n.extractingAudio,
        progress: null,
        color: Colors.orange,
      );
    }

    if (state is Transcribing) {
      final s = state as Transcribing;
      String label = s.progress > 0
          ? l10n.processingTranscription
          : l10n.preprocessingStatus;
      return _buildProgressRow(
        context,
        icon: Icons.mic_rounded,
        label: label,
        progress: s.progress > 0 ? s.progress / 100.0 : null,
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
      return Row(
        children: [
          const Icon(Icons.error_rounded, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.message,
              style: theme.textTheme.bodySmall?.copyWith(
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
