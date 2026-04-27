// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Caption Trans';

  @override
  String get settings => 'Settings';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get error => 'Error';

  @override
  String get stepSelectVideo => 'Select Video';

  @override
  String get clickToSelectVideo => 'Click to select a video file';

  @override
  String get supportedFormats => 'Supports MP4, MKV, AVI, MOV, WebM and more';

  @override
  String get videoSelected => 'Video file selected';

  @override
  String get changeFile => 'Change file';

  @override
  String get clear => 'Clear';

  @override
  String get stepExtractSubtitles => 'Extract Subtitles';

  @override
  String get whisperModel => 'Model';

  @override
  String get sourceVideoLanguage => 'Source Video Language';

  @override
  String get sourceVideoLanguageHint =>
      'Selecting source video language can improve transcription efficiency and accuracy.';

  @override
  String get diskUsage => 'Disk';

  @override
  String get memoryUsage => 'Memory';

  @override
  String get transcriptionQuality => 'Quality';

  @override
  String get qualityLow => 'Low';

  @override
  String get qualityBasic => 'Basic';

  @override
  String get qualityGood => 'Good';

  @override
  String get qualityExcellent => 'Excellent';

  @override
  String get qualitySuperior => 'Superior (Recommended)';

  @override
  String get qualityBest => 'Best';

  @override
  String get extract => 'Extract';

  @override
  String get preparingRuntime => 'Preparing runtime...';

  @override
  String get runtimeChecking => 'Checking runtime...';

  @override
  String get runtimeDownloading => 'Downloading runtime package...';

  @override
  String get runtimeExtracting => 'Extracting runtime package...';

  @override
  String get runtimeCreatingEnvironment => 'Creating Python environment...';

  @override
  String get runtimeInstallingDependencies =>
      'Installing dependencies (first run may take a while)...';

  @override
  String get runtimeStartingSidecar => 'Starting runtime...';

  @override
  String get transcodingAudio => 'Transcoding media to audio...';

  @override
  String get transcribingStatus => 'Transcribing...';

  @override
  String get transcriptionLoadingAudio => 'Loading audio...';

  @override
  String get transcriptionPreparingModel =>
      'Preparing model (download on first run if needed)...';

  @override
  String get transcriptionRunning => 'Transcribing audio...';

  @override
  String get transcriptionAligning => 'Aligning timestamps...';

  @override
  String get transcriptionFinalizing => 'Finalizing transcription result...';

  @override
  String get extractingAudio => 'Extracting audio from video...';

  @override
  String get processingTranscription => 'Transcription in progress...';

  @override
  String get preprocessingStatus =>
      'Preprocessing: Transcoding and silence detection...';

  @override
  String segmentsExtracted(int count, String lang) {
    return '$count segments extracted ($lang)';
  }

  @override
  String get stepTranslate => 'Translate';

  @override
  String get geminiApiKey => 'API Key';

  @override
  String get enterApiKey => 'Enter your API Key';

  @override
  String get aiProvider => 'AI Provider';

  @override
  String get geminiModel => 'AI Model';

  @override
  String get enterGeminiModel => 'e.g., gemini-2.0-flash, gpt-4o';

  @override
  String get targetLanguage => 'Target Language';

  @override
  String get translate => 'Translate';

  @override
  String get continueTranslation => 'Continue Translation';

  @override
  String retryFailedTranslations(int count) {
    return 'Retry Failed ($count)';
  }

  @override
  String get retranslate => 'Retranslate';

  @override
  String get initializingTranslation => 'Initializing translation...';

  @override
  String translatingProgress(int completed, int total) {
    return 'Translating subtitles ($completed/$total)...';
  }

  @override
  String segmentsTranslated(int count, String lang) {
    return '$count segments translated to $lang';
  }

  @override
  String get stepPreviewExport => 'Preview & Export';

  @override
  String get exportOriginal => 'Export Original';

  @override
  String get exportTranslated => 'Export Translated';

  @override
  String get exportBilingual => 'Export Bilingual';

  @override
  String get noSubtitlesYet => 'No subtitles yet';

  @override
  String get completeTranscriptionFirst =>
      'Complete the transcription step to see subtitles here';

  @override
  String exportedTo(String path) {
    return 'Exported to $path';
  }

  @override
  String get exportSrt => 'Export SRT';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get downloadSourceTitle => 'Download source';

  @override
  String get downloadSourceHint =>
      'Choose which source profile WhisperX should use for runtime, dependency, and model downloads. You can change it later in Settings.';

  @override
  String get downloadSourceSectionTitle => 'WhisperX downloads';

  @override
  String get downloadSourceSectionHint =>
      'Applies to Python runtime, pip dependencies, PyTorch wheels, and model downloads.';

  @override
  String get downloadSourcePromptTitle => 'Choose download source';

  @override
  String get downloadSourcePromptMessage =>
      'Before WhisperX downloads runtime files, dependencies, and models for the first time, choose which source profile to use. You can change this later in Settings.';

  @override
  String get downloadSourceGlobal => 'International source';

  @override
  String get downloadSourceGlobalDescription =>
      'Use official GitHub, PyPI, PyTorch, and Hugging Face sources. Recommended outside mainland China.';

  @override
  String get downloadSourceChina => 'Mainland China source';

  @override
  String get downloadSourceChinaDescription =>
      'Use mainland mirrors when available for runtime, PyPI, PyTorch, and Hugging Face downloads.';

  @override
  String get downloadSourceUnset => 'Not selected';

  @override
  String get changeDownloadSource => 'Change download source';

  @override
  String get downloadSourceUpdated => 'Download source updated.';

  @override
  String get apiKeyHint => 'Paste your API key here';

  @override
  String get getApiKeyHint =>
      'Get your API key from the selected AI provider\'s dashboard';

  @override
  String get language => 'Language';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get paste => 'Paste';

  @override
  String batchSizeLabel(Object count) {
    return 'Translate $count subtitles per batch';
  }

  @override
  String get batchSizeHint =>
      'More: Faster, better context. Less: More stable, but more API requests.';

  @override
  String get recentProjects => 'Recent Projects';

  @override
  String get viewAll => 'View All';

  @override
  String get noProjects => 'No projects history';

  @override
  String progressLabel(int completed, int total) {
    return 'Progress: $completed / $total';
  }

  @override
  String get detect => 'Detect';

  @override
  String get clickDetectToFetchModels =>
      'Please click \"Detect\" to fetch available models';

  @override
  String get savedProvidersTitle => 'Saved Providers';

  @override
  String get savedProvidersEmpty => 'No saved providers';

  @override
  String get savedProvidersHint =>
      'Automatically saved locally after API verification succeeds';

  @override
  String get appUpdate => 'Application';

  @override
  String get currentVersion => 'Current version';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get checkingForUpdates => 'Checking for updates...';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String updateAvailableMessage(String latest, String current) {
    return 'Version $latest is available. You are currently on $current.';
  }

  @override
  String get downloadUpdate => 'Download update';

  @override
  String alreadyLatestVersion(String version) {
    return 'You\'re on the latest version ($version).';
  }

  @override
  String get updateCheckFailed => 'Failed to check for updates.';

  @override
  String batchQueueFinished(int count) {
    return 'Batch queue finished ($count files).';
  }

  @override
  String autoExported(String path) {
    return 'Auto exported: $path';
  }

  @override
  String autoExportFailed(int maxAttempts, String fileName) {
    return 'Auto export failed after $maxAttempts attempts: $fileName';
  }

  @override
  String get selectedFilesAlreadyInQueue =>
      'Selected files are already in queue.';

  @override
  String batchQueueAdded(int count) {
    return 'Added $count file(s) to queue.';
  }

  @override
  String batchQueueAddedEnableAuto(int count) {
    return 'Added $count file(s). Enable auto extraction to process queue.';
  }

  @override
  String batchQueueAddedWithDuplicates(int addedCount, int duplicateCount) {
    return 'Added $addedCount file(s), $duplicateCount duplicate task(s) were skipped.';
  }

  @override
  String get queueAutomationSettingsTitle => 'Queue automation settings';

  @override
  String get removeQueueTask => 'Remove task';

  @override
  String get cannotRemoveActiveQueueTask =>
      'Cannot remove the task currently being processed.';

  @override
  String queueTaskRemoved(String fileName) {
    return 'Removed from queue: $fileName';
  }

  @override
  String get autoProcessExtractionQueueTitle => 'Auto process extraction queue';

  @override
  String get autoProcessExtractionQueueSubtitle =>
      'Run extraction continuously for selected files (max 3 attempts per file).';

  @override
  String get autoProcessTranslationQueueTitle =>
      'Auto process translation queue';

  @override
  String get autoProcessTranslationQueueSubtitle =>
      'Retry translation errors automatically and continue queue (max 3 attempts per file).';

  @override
  String maxRetriesPerStage(int maxRetries) {
    return 'Max retries per stage: $maxRetries';
  }

  @override
  String batchQueueTitle(int count) {
    return 'Batch Queue ($count)';
  }

  @override
  String get queueRunning => 'Running...';

  @override
  String get queueIdle => 'Idle';

  @override
  String get queueStagePending => 'Pending';

  @override
  String get queueStageExtracting => 'Extracting';

  @override
  String get queueStageExtractFailed => 'Extract Failed';

  @override
  String get queueStageExtracted => 'Extracted';

  @override
  String get queueStageTranslating => 'Translating';

  @override
  String get queueStageTranslationFailed => 'Translation Failed';

  @override
  String get queueStageExporting => 'Exporting';

  @override
  String get queueStageExportFailed => 'Export Failed';

  @override
  String get queueStageCompleted => 'Completed';

  @override
  String get queueStageSkipped => 'Skipped';

  @override
  String get releaseNotes => 'Release notes';
}
