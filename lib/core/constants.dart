import 'package:caption_trans/l10n/app_localizations.dart';

/// Information about a Whisper model.
class WhisperModelInfo {
  final String name;
  final String diskUsage;
  final String memoryUsage;
  final String Function(AppLocalizations) quality;

  const WhisperModelInfo({
    required this.name,
    required this.diskUsage,
    required this.memoryUsage,
    required this.quality,
  });
}

/// Application-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Caption Trans';

  /// Supported Whisper models with detailed information.
  static final Map<String, WhisperModelInfo> whisperModels = {
    'tiny': WhisperModelInfo(
      name: 'tiny',
      diskUsage: '~75 MB',
      memoryUsage: '~273 MB',
      quality: (l) => l.qualityLow,
    ),
    'base': WhisperModelInfo(
      name: 'base',
      diskUsage: '~142 MB',
      memoryUsage: '~388 MB',
      quality: (l) => l.qualityBasic,
    ),
    'small': WhisperModelInfo(
      name: 'small',
      diskUsage: '~466 MB',
      memoryUsage: '~852 MB',
      quality: (l) => l.qualityGood,
    ),
    'medium': WhisperModelInfo(
      name: 'medium',
      diskUsage: '~1.5 GB',
      memoryUsage: '~2.1 GB',
      quality: (l) => l.qualityExcellent,
    ),
    'large-v3-turbo': WhisperModelInfo(
      name: 'large-v3-turbo',
      diskUsage: '~1.5 GB',
      memoryUsage: '~2.0 GB',
      quality: (l) => l.qualitySuperior,
    ),
    'large-v3': WhisperModelInfo(
      name: 'large-v3',
      diskUsage: '~2.9 GB',
      memoryUsage: '~3.9 GB',
      quality: (l) => l.qualityBest,
    ),
  };

  static const String defaultWhisperModel = 'large-v3-turbo';

  /// Supported languages for translation target.
  static const Map<String, String> supportedLanguages = {
    'zh': '中文',
    'en': 'English',
    'ja': '日本語',
    'ko': '한국어',
    'fr': 'Français',
    'de': 'Deutsch',
    'es': 'Español',
    'pt': 'Português',
    'ru': 'Русский',
    'ar': 'العربية',
    'auto': 'Auto detect(Not recommended)',
  };

  /// Supported video file extensions.
  static const List<String> videoExtensions = [
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    'm4v',
  ];
}
