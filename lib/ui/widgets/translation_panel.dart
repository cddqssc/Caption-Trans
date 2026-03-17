import 'package:flutter/material.dart';
import '../../blocs/transcription/transcription_state.dart';
import '../../blocs/translation/translation_state.dart';
import '../../core/constants.dart';
import 'package:caption_trans/l10n/app_localizations.dart';

const Map<String, String> defaultLlmBaseUrls = {
  'DeepSeek': 'https://api.deepseek.com/v1',
  'Qwen': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  'Kimi': 'https://api.moonshot.cn/v1',
  'GLM': 'https://open.bigmodel.cn/api/paas/v4',
  '豆包': 'https://ark.cn-beijing.volces.com/api/v3',
  '零一万物': 'https://api.lingyiwanwu.com/v1',
  '百川智能': 'https://api.baichuan-ai.com/v1',
  '文心一言': 'https://qianfan.baidubce.com/v2',
  'OpenAI': 'https://api.openai.com/v1',
  'Gemini (Google)': 'https://generativelanguage.googleapis.com/v1beta/openai',
  'Ollama': 'http://localhost:11434/v1',
  'SiliconFlow': 'https://api.siliconflow.cn/v1',
};

/// Panel for configuring and starting translation.
class TranslationPanel extends StatelessWidget {
  final TranscriptionState transcriptionState;
  final TranslationState translationState;
  final String targetLanguage;
  final String llmProvider;
  final String llmBaseUrl;
  final String apiKey;
  final String targetModel;
  final int batchSize;
  final List<String> availableModels;
  final bool isLoadingModels;
  final ValueChanged<String> onLlmProviderChanged;
  final ValueChanged<String> onLlmBaseUrlChanged;
  final ValueChanged<String> onTargetLanguageChanged;
  final ValueChanged<String> onApiKeyChanged;
  final ValueChanged<String> onTargetModelChanged;
  final ValueChanged<int> onBatchSizeChanged;
  final VoidCallback onCheckModels;
  final VoidCallback onStartTranslation;
  final VoidCallback onCancelTranslation;

  const TranslationPanel({
    super.key,
    required this.transcriptionState,
    required this.translationState,
    required this.targetLanguage,
    required this.llmProvider,
    required this.llmBaseUrl,
    required this.apiKey,
    required this.targetModel,
    required this.batchSize,
    required this.availableModels,
    required this.isLoadingModels,
    required this.onLlmProviderChanged,
    required this.onLlmBaseUrlChanged,
    required this.onTargetLanguageChanged,
    required this.onApiKeyChanged,
    required this.onTargetModelChanged,
    required this.onBatchSizeChanged,
    required this.onCheckModels,
    required this.onStartTranslation,
    required this.onCancelTranslation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final modelNameMaxChars = MediaQuery.of(context).size.width < 600 ? 26 : 48;
    final modelOptions = availableModels.toSet().toList();

    // Ensure the current llmProvider acts correctly if not in map
    final currentProviderValue = defaultLlmBaseUrls.containsKey(llmProvider)
        ? llmProvider
        : (defaultLlmBaseUrls.keys.contains('Gemini (Google)')
              ? 'Gemini (Google)'
              : defaultLlmBaseUrls.keys.first);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.aiProvider,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: currentProviderValue,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.cloud_rounded, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: defaultLlmBaseUrls.keys.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(
                    p,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _isTranslating
                  ? null
                  : (v) {
                      if (v != null) {
                        onLlmProviderChanged(v);
                      }
                    },
            ),
            const SizedBox(height: 20),
            Text(
              'Base URL',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                hintText: 'e.g. https://api.openai.com/v1',
                isDense: true,
                prefixIcon: Icon(Icons.link_rounded, size: 18),
              ),
              onChanged: onLlmBaseUrlChanged,
              controller: TextEditingController(
                text: llmBaseUrl,
              )..selection = TextSelection.collapsed(offset: llmBaseUrl.length),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.geminiApiKey,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: l10n.enterApiKey,
                      isDense: true,
                      prefixIcon: const Icon(Icons.key_rounded, size: 18),
                    ),
                    onChanged: onApiKeyChanged,
                    controller: TextEditingController(text: apiKey)
                      ..selection = TextSelection.collapsed(
                        offset: apiKey.length,
                      ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _isTranslating || apiKey.isEmpty
                      ? null
                      : onCheckModels,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Text(l10n.detect),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              l10n.geminiModel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            isLoadingModels
                ? const LinearProgressIndicator()
                : availableModels.isEmpty
                ? Text(
                    l10n.clickDetectToFetchModels,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 13,
                    ),
                  )
                : DropdownButtonFormField<String>(
                    initialValue: modelOptions.contains(targetModel)
                        ? targetModel
                        : modelOptions.first,
                    itemHeight: null,
                    decoration: InputDecoration(
                      hintText: l10n.enterGeminiModel,
                      isDense: true,
                      prefixIcon: const Icon(
                        Icons.psychology_rounded,
                        size: 18,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    selectedItemBuilder: (context) => modelOptions.map((m) {
                      final truncated = _truncateModelName(
                        m,
                        maxChars: modelNameMaxChars,
                      );
                      return Tooltip(
                        message: m,
                        waitDuration: const Duration(milliseconds: 500),
                        child: Text(
                          truncated,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    items: modelOptions.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(
                          m,
                          style: const TextStyle(fontSize: 14),
                          softWrap: true,
                        ),
                      );
                    }).toList(),
                    onChanged: _isTranslating
                        ? null
                        : (v) {
                            if (v != null) onTargetModelChanged(v);
                          },
                  ),
            const SizedBox(height: 20),
            Text(
              l10n.batchSizeLabel(batchSize),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Slider(
                      value: batchSize.toDouble(),
                      min: 1,
                      max: 100,
                      divisions: 99,
                      onChanged: _isTranslating
                          ? null
                          : (v) => onBatchSizeChanged(v.round()),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    batchSize.toString(),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              l10n.batchSizeHint,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.targetLanguage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: targetLanguage,
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
                    onChanged: _isTranslating
                        ? null
                        : (v) {
                            if (v != null) onTargetLanguageChanged(v);
                          },
                  ),
                ),
                const SizedBox(width: 16),
                _buildStartButton(context, l10n),
              ],
            ),
            if (_isTranslating ||
                translationState is TranslationComplete ||
                translationState is TranslationError ||
                translationState is TranslationCancelled)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _buildStatusWidget(context, l10n),
              ),
          ],
        ),
      ),
    );
  }

  bool get _isTranslating => translationState is TranslationInProgress;

  bool get _canStart =>
      transcriptionState is TranscriptionComplete &&
      apiKey.isNotEmpty &&
      availableModels.isNotEmpty &&
      translationState is! TranslationInProgress;

  String _truncateModelName(String model, {required int maxChars}) {
    if (model.length <= maxChars || maxChars <= 6) {
      return model;
    }

    final keep = maxChars - 3;
    final head = (keep * 0.65).floor();
    final tail = keep - head;
    return '${model.substring(0, head)}...${model.substring(model.length - tail)}';
  }

  Widget _buildStartButton(BuildContext context, AppLocalizations l10n) {
    if (_isTranslating) {
      final errorColor = Theme.of(context).colorScheme.error;
      return OutlinedButton.icon(
        onPressed: onCancelTranslation,
        icon: Icon(Icons.stop_circle_rounded, size: 18, color: errorColor),
        style: OutlinedButton.styleFrom(
          foregroundColor: errorColor,
          side: BorderSide(color: errorColor.withValues(alpha: 0.6)),
        ),
        label: Text(l10n.cancel),
      );
    }

    return FilledButton(
      onPressed: _canStart ? onStartTranslation : null,
      child: Text(l10n.translate),
    );
  }

  Widget _buildStatusWidget(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    if (translationState is TranslationInProgress) {
      final s = translationState as TranslationInProgress;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.translate_rounded,
                size: 16,
                color: Colors.tealAccent,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.translatingProgress(s.completed, s.total),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.progress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(Colors.tealAccent),
              minHeight: 4,
            ),
          ),
        ],
      );
    }

    if (translationState is TranslationComplete) {
      final s = translationState as TranslationComplete;
      final langName =
          AppConstants.supportedLanguages[s.config.targetLanguage] ??
          s.config.targetLanguage;
      return Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Colors.greenAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.segmentsTranslated(s.translatedSegments.length, langName),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.greenAccent,
            ),
          ),
        ],
      );
    }

    if (translationState is TranslationError) {
      final s = translationState as TranslationError;
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

    if (translationState is TranslationCancelled) {
      final s = translationState as TranslationCancelled;
      final errorColor = theme.colorScheme.error;
      return Row(
        children: [
          Icon(Icons.stop_circle_rounded, color: errorColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.message,
              style: theme.textTheme.bodySmall?.copyWith(color: errorColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
