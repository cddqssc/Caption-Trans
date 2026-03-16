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
  String get whisperModel => 'Whisper Model';

  @override
  String get diskUsage => 'Disk Usage';

  @override
  String get memoryUsage => 'Memory/VRAM Usage';

  @override
  String get transcriptionQuality => 'Transcription Quality';

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
  String downloadingModel(String name) {
    return 'Downloading model $name...';
  }

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
}
