import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../services/settings_service.dart';
import '../services/translation/translation_service.dart';
import '../blocs/transcription/transcription_bloc.dart';
import '../blocs/transcription/transcription_event.dart';
import '../blocs/transcription/transcription_state.dart';
import '../blocs/translation/translation_bloc.dart';
import '../blocs/translation/translation_event.dart';
import '../blocs/translation/translation_state.dart';
import '../core/constants.dart';
import 'package:caption_trans/l10n/app_localizations.dart';
import '../core/utils/srt_parser.dart';
import '../models/translation_config.dart';
import 'widgets/video_picker_card.dart';
import 'widgets/transcription_panel.dart';
import 'widgets/translation_panel.dart';
import 'widgets/subtitle_preview.dart';
import 'widgets/settings_dialog.dart';
import 'project_list_page.dart';
import '../models/project.dart';
import 'package:uuid/uuid.dart';
import '../blocs/project/project_bloc.dart';
import '../blocs/project/project_event.dart';
import '../blocs/project/project_state.dart';
import '../models/subtitle_segment.dart';

/// Main application page with step-by-step workflow.
class HomePage extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  final SettingsService settingsService;

  const HomePage({
    super.key,
    required this.onLocaleChanged,
    required this.settingsService,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedModel = AppConstants.defaultWhisperModel;
  String _targetLanguage = 'zh';
  String _apiKey = '';
  String _targetModel = 'gemini-2.0-flash';
  String _llmProvider = 'Gemini (Google)';
  String _llmBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/openai';
  bool _bilingual = true;
  int _batchSize = 25;
  List<String> _availableModels = [];
  bool _isLoadingModels = false;

  Project? _activeProject;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _apiKey = widget.settingsService.geminiApiKey;
      _targetModel = widget.settingsService.geminiModel;
      _llmProvider = widget.settingsService.llmProvider;
      _llmBaseUrl = widget.settingsService.llmBaseUrl;
      _targetLanguage = widget.settingsService.targetLanguage;
      _bilingual = widget.settingsService.bilingual;
      _batchSize = widget.settingsService.batchSize;
    });

    if (_apiKey.isNotEmpty) {
      _fetchModels();
    }
  }

  Future<void> _fetchModels() async {
    if (_apiKey.isEmpty) return;

    setState(() => _isLoadingModels = true);
    try {
      final service = TranslationService();
      final models = await service.listModels(
        TranslationConfig(
          providerId: _llmProvider,
          apiKey: _apiKey,
          baseUrl: _llmBaseUrl,
          sourceLanguage: 'en', // dummy
          targetLanguage: 'zh', // dummy
        ),
      );

      if (mounted) {
        setState(() {
          _availableModels = models;
          if (!_availableModels.contains(_targetModel)) {
            if (_availableModels.isNotEmpty) {
              _targetModel = _availableModels.first;
            }
          }
          _isLoadingModels = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _availableModels = [_targetModel];
          _isLoadingModels = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch models. Check Base URL or API Key.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Column(
        children: [
          _buildAppBar(context, l10n),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Step 1: Video Selection
                      _buildSectionHeader(
                        context,
                        icon: Icons.video_library_rounded,
                        title: 'Step 1: ${l10n.stepSelectVideo}',
                        number: '1',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 1,
                            child: BlocConsumer<TranscriptionBloc, TranscriptionState>(
                              listener: (context, state) {
                                if (state is TranscriptionComplete) {
                                  if (_activeProject == null ||
                                      _activeProject!.name != state.fileName) {
                                    // Create a new project when transcription finishes initially
                                    _activeProject = Project(
                                      id: const Uuid().v4(),
                                      name: state.fileName,
                                      videoPath: state.videoPath,
                                      createdAt: DateTime.now(),
                                      updatedAt: DateTime.now(),
                                      transcription: state.result,
                                      translationConfig: null,
                                    );
                                    context.read<ProjectBloc>().add(
                                      AddProject(_activeProject!),
                                    );
                                  } else {
                                    // Update existing active project if for some reason transcription completes again
                                    // Should not really happen on normal resume since it bypasses extraction
                                  }
                                } else if (state is TranscriptionInitial ||
                                    state is VideoSelected) {
                                  _activeProject =
                                      null; // Reset on new video pick
                                }
                              },
                              builder: (context, state) {
                                return VideoPickerCard(
                                  selectedFileName: _getFileName(state),
                                  onPickVideo: () => _pickVideo(context),
                                  onClear: state is! TranscriptionInitial
                                      ? () => context
                                            .read<TranscriptionBloc>()
                                            .add(const ResetTranscription())
                                      : null,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(flex: 1, child: _buildEmbeddedProjectList()),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Step 2: Transcription
                      _buildSectionHeader(
                        context,
                        icon: Icons.mic_rounded,
                        title: 'Step 2: ${l10n.stepExtractSubtitles}',
                        number: '2',
                      ),
                      const SizedBox(height: 12),
                      BlocBuilder<TranscriptionBloc, TranscriptionState>(
                        builder: (context, state) {
                          return TranscriptionPanel(
                            state: state,
                            selectedModel: _selectedModel,
                            onModelChanged: (model) =>
                                setState(() => _selectedModel = model),
                            onStartTranscription: () {
                              context.read<TranscriptionBloc>().add(
                                StartTranscription(modelName: _selectedModel),
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // Step 3: Translation
                      _buildSectionHeader(
                        context,
                        icon: Icons.translate_rounded,
                        title: 'Step 3: ${l10n.stepTranslate}',
                        number: '3',
                      ),
                      const SizedBox(height: 12),
                      BlocConsumer<TranslationBloc, TranslationState>(
                        listener: (context, state) {
                          if (state is TranslationError) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(state.message),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          } else if (state is TranslationInProgress &&
                              state.partialSegments != null) {
                            if (_activeProject != null) {
                              final updatedResult = _activeProject!
                                  .transcription
                                  .copyWith(segments: state.partialSegments!);
                              _activeProject = _activeProject!.copyWith(
                                transcription: updatedResult,
                                updatedAt: DateTime.now(),
                              );
                              context.read<ProjectBloc>().add(
                                UpdateProject(_activeProject!),
                              );
                            }
                          } else if (state is TranslationComplete) {
                            if (_activeProject != null) {
                              final updatedResult = _activeProject!
                                  .transcription
                                  .copyWith(segments: state.translatedSegments);
                              _activeProject = _activeProject!.copyWith(
                                transcription: updatedResult,
                                updatedAt: DateTime.now(),
                                translationConfig: state.config,
                              );
                              context.read<ProjectBloc>().add(
                                UpdateProject(_activeProject!),
                              );
                            }
                          }
                        },
                        builder: (context, translationState) {
                          return BlocBuilder<
                            TranscriptionBloc,
                            TranscriptionState
                          >(
                            builder: (context, transcriptionState) {
                              return TranslationPanel(
                                transcriptionState: transcriptionState,
                                translationState: translationState,
                                llmProvider: _llmProvider,
                                llmBaseUrl: _llmBaseUrl,
                                onLlmProviderChanged: (provider) {
                                  setState(() {
                                    _llmProvider = provider;
                                    _targetModel = ''; // reset model
                                  });
                                  widget.settingsService.setLlmProvider(
                                    provider,
                                  );
                                  if (_apiKey.isNotEmpty) {
                                    _fetchModels();
                                  }
                                },
                                onLlmBaseUrlChanged: (url) {
                                  setState(() => _llmBaseUrl = url);
                                  widget.settingsService.setLlmBaseUrl(url);
                                },
                                onCheckModels: () => _fetchModels(),
                                targetLanguage: _targetLanguage,
                                apiKey: _apiKey,
                                targetModel: _targetModel,
                                availableModels: _availableModels,
                                isLoadingModels: _isLoadingModels,
                                onTargetLanguageChanged: (lang) {
                                  setState(() => _targetLanguage = lang);
                                  widget.settingsService.setTargetLanguage(
                                    lang,
                                  );
                                },
                                onApiKeyChanged: (key) {
                                  setState(() => _apiKey = key);
                                  widget.settingsService.setGeminiApiKey(key);
                                  _fetchModels();
                                },
                                onTargetModelChanged: (model) {
                                  setState(() => _targetModel = model);
                                  widget.settingsService.setGeminiModel(model);
                                },
                                batchSize: _batchSize,
                                onBatchSizeChanged: (size) {
                                  setState(() => _batchSize = size);
                                  widget.settingsService.setBatchSize(size);
                                },
                                onStartTranslation: () {
                                  if (transcriptionState
                                      is TranscriptionComplete) {
                                    context.read<TranslationBloc>().add(
                                      StartTranslation(
                                        segments:
                                            transcriptionState.result.segments,
                                        config: TranslationConfig(
                                          providerId: _llmProvider,
                                          apiKey: _apiKey,
                                          baseUrl: _llmBaseUrl,
                                          model: _targetModel,
                                          sourceLanguage: transcriptionState
                                              .result
                                              .language,
                                          targetLanguage: _targetLanguage,
                                          batchSize: _batchSize,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // Step 4: Preview & Export
                      _buildSectionHeader(
                        context,
                        icon: Icons.subtitles_rounded,
                        title: 'Step 4: ${l10n.stepPreviewExport}',
                        number: '4',
                      ),
                      const SizedBox(height: 12),
                      _buildPreviewAndExport(context),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 186, 186, 186),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 32,
              height: 32,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.appName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => _showSettings(context),
            tooltip: l10n.settings,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String number,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPreviewAndExport(BuildContext context) {
    return BlocBuilder<TranslationBloc, TranslationState>(
      builder: (context, translationState) {
        return BlocBuilder<TranscriptionBloc, TranscriptionState>(
          builder: (context, transcriptionState) {
            List<SubtitleSegment>? segments;
            bool hasTranslation = false;

            if (translationState is TranslationComplete) {
              segments = translationState.translatedSegments;
              hasTranslation = true;
            } else if (transcriptionState is TranscriptionComplete) {
              segments = transcriptionState.result.segments;
              // Check if the loaded project naturally has translations
              hasTranslation = segments.any(
                (s) => s.translatedText?.isNotEmpty == true,
              );
            }

            return SubtitlePreview(
              segments: segments,
              hasTranslation:
                  hasTranslation || translationState is TranslationComplete,
              bilingual: _bilingual,
              onBilingualChanged: (v) {
                setState(() => _bilingual = v);
                widget.settingsService.setBilingual(v);
              },
              onExportOriginal: segments != null
                  ? () => _exportSrt(
                      context,
                      segments!.cast<dynamic>(),
                      false,
                      false,
                    )
                  : null,
              onExportTranslated: hasTranslation && segments != null
                  ? () => _exportSrt(
                      context,
                      segments!.cast<dynamic>(),
                      true,
                      false,
                    )
                  : null,
              onExportBilingual: hasTranslation && segments != null
                  ? () => _exportSrt(
                      context,
                      segments!.cast<dynamic>(),
                      false,
                      true,
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  String? _getFileName(TranscriptionState state) {
    if (state is VideoSelected) return state.fileName;
    if (state is ModelDownloading) return state.fileName;
    if (state is AudioExtracting) return state.fileName;
    if (state is Transcribing) return state.fileName;
    if (state is TranscriptionComplete) return state.fileName;
    if (state is TranscriptionError) return state.fileName;
    return null;
  }

  Future<void> _pickVideo(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.videoExtensions,
    );

    if (result != null && result.files.single.path != null) {
      if (context.mounted) {
        context.read<TranscriptionBloc>().add(
          SelectVideo(result.files.single.path!),
        );
        context.read<TranslationBloc>().add(const ResetTranslation());
      }
    }
  }

  Future<void> _exportSrt(
    BuildContext context,
    List<dynamic> segments,
    bool translatedOnly,
    bool bilingual,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final srtContent = SrtParser.generate(
      segments.cast(),
      useTranslation: translatedOnly,
      bilingual: bilingual,
    );

    final suffix = bilingual
        ? '_bilingual'
        : (translatedOnly ? '_translated' : '_original');

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: l10n.exportSrt,
      fileName: 'subtitles$suffix.srt',
      type: FileType.custom,
      allowedExtensions: ['srt'],
    );

    if (outputPath != null) {
      await File(outputPath).writeAsString(srtContent);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.exportedTo(outputPath)),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    }
  }

  void _showSettings(BuildContext context) {
    final locale = Localizations.localeOf(context);
    showDialog(
      context: context,
      builder: (_) => SettingsDialog(
        currentLocale: locale,
        onLocaleChanged: widget.onLocaleChanged,
      ),
    );
  }

  Widget _buildEmbeddedProjectList() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 175, // Match typical VideoPickerCard height
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, size: 18),
                const SizedBox(width: 8),
                Text(
                  l10n.recentProjects,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _openProjects(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l10n.viewAll,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: BlocBuilder<ProjectBloc, ProjectState>(
              builder: (context, state) {
                if (state is ProjectLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ProjectLoaded) {
                  final projects = state.projects;
                  if (projects.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.noProjects,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: projects.length > 5
                        ? 5
                        : projects.length, // Show top 5
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      final isSelected = _activeProject?.id == project.id;

                      final total = project.transcription.segments.length;
                      final translated = project.transcription.segments
                          .where((s) => s.translatedText?.isNotEmpty == true)
                          .length;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _loadProject(project),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primary.withValues(alpha: 0.1)
                                  : null,
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        project.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n.progressLabel(translated, total),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProjects(BuildContext context) async {
    final selectedProject = await Navigator.push<Project>(
      context,
      MaterialPageRoute(builder: (_) => const ProjectListPage()),
    );
    if (selectedProject != null) {
      _loadProject(selectedProject);
    }
  }

  void _loadProject(Project project) {
    setState(() {
      _activeProject = project;
      if (project.translationConfig != null) {
        _targetLanguage = project.translationConfig!.targetLanguage;
        // Restore other config if needed
        if (project.translationConfig!.model != null) {
          _targetModel = project.translationConfig!.model!;
        }
      }
    });

    // Clear translation bloc to ready it for continuation
    context.read<TranslationBloc>().add(const ResetTranslation());

    // Resume transcription bloc by feeding raw result immediately
    context.read<TranscriptionBloc>().add(
      LoadTranscriptionFromProject(
        videoPath: project.videoPath,
        fileName: project.name,
        result: project.transcription,
      ),
    );
  }
}
