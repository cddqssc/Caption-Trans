import 'package:flutter/material.dart';
import '../../models/subtitle_segment.dart';
import 'package:caption_trans/l10n/app_localizations.dart';

/// Preview panel for displaying extracted/translated subtitles.
class SubtitlePreview extends StatelessWidget {
  final List<SubtitleSegment>? segments;
  final bool hasTranslation;
  final bool bilingual;
  final ValueChanged<bool> onBilingualChanged;
  final VoidCallback? onExportOriginal;
  final VoidCallback? onExportTranslated;
  final VoidCallback? onExportBilingual;

  const SubtitlePreview({
    super.key,
    this.segments,
    this.hasTranslation = false,
    this.bilingual = true,
    required this.onBilingualChanged,
    this.onExportOriginal,
    this.onExportTranslated,
    this.onExportBilingual,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (segments != null && segments!.isNotEmpty)
              _buildExportRow(context),
            if (segments != null && segments!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
            ],
            if (segments == null || segments!.isEmpty)
              _buildEmptyState(context)
            else
              _buildSubtitleList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildExportRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ExportButton(
          label: l10n.exportOriginal,
          icon: Icons.text_snippet_rounded,
          onPressed: onExportOriginal,
        ),
        if (hasTranslation)
          _ExportButton(
            label: l10n.exportTranslated,
            icon: Icons.translate_rounded,
            onPressed: onExportTranslated,
          ),
        if (hasTranslation)
          _ExportButton(
            label: l10n.exportBilingual,
            icon: Icons.share,
            onPressed: onExportBilingual,
            primary: true,
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.subtitles_off_rounded,
              size: 40,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noSubtitlesYet,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            Text(
              l10n.completeTranscriptionFirst,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleList(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: segments!.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
        itemBuilder: (context, index) {
          final seg = segments![index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    _formatTimestamp(seg.startTime),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seg.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                      if (hasTranslation && seg.translatedText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          seg.translatedText!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.tealAccent.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds';
  }
}

class _ExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  const _ExportButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13)),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
    );
  }
}
