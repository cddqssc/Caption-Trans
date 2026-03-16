import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Caption Trans'**
  String get appName;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @stepSelectVideo.
  ///
  /// In en, this message translates to:
  /// **'Select Video'**
  String get stepSelectVideo;

  /// No description provided for @clickToSelectVideo.
  ///
  /// In en, this message translates to:
  /// **'Click to select a video file'**
  String get clickToSelectVideo;

  /// No description provided for @supportedFormats.
  ///
  /// In en, this message translates to:
  /// **'Supports MP4, MKV, AVI, MOV, WebM and more'**
  String get supportedFormats;

  /// No description provided for @videoSelected.
  ///
  /// In en, this message translates to:
  /// **'Video file selected'**
  String get videoSelected;

  /// No description provided for @changeFile.
  ///
  /// In en, this message translates to:
  /// **'Change file'**
  String get changeFile;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @stepExtractSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Extract Subtitles'**
  String get stepExtractSubtitles;

  /// No description provided for @whisperModel.
  ///
  /// In en, this message translates to:
  /// **'Whisper Model'**
  String get whisperModel;

  /// No description provided for @diskUsage.
  ///
  /// In en, this message translates to:
  /// **'Disk Usage'**
  String get diskUsage;

  /// No description provided for @memoryUsage.
  ///
  /// In en, this message translates to:
  /// **'Memory/VRAM Usage'**
  String get memoryUsage;

  /// No description provided for @transcriptionQuality.
  ///
  /// In en, this message translates to:
  /// **'Transcription Quality'**
  String get transcriptionQuality;

  /// No description provided for @qualityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get qualityLow;

  /// No description provided for @qualityBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get qualityBasic;

  /// No description provided for @qualityGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get qualityGood;

  /// No description provided for @qualityExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get qualityExcellent;

  /// No description provided for @qualitySuperior.
  ///
  /// In en, this message translates to:
  /// **'Superior (Recommended)'**
  String get qualitySuperior;

  /// No description provided for @qualityBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get qualityBest;

  /// No description provided for @extract.
  ///
  /// In en, this message translates to:
  /// **'Extract'**
  String get extract;

  /// No description provided for @downloadingModel.
  ///
  /// In en, this message translates to:
  /// **'Downloading model {name}...'**
  String downloadingModel(String name);

  /// No description provided for @extractingAudio.
  ///
  /// In en, this message translates to:
  /// **'Extracting audio from video...'**
  String get extractingAudio;

  /// No description provided for @processingTranscription.
  ///
  /// In en, this message translates to:
  /// **'Transcription in progress...'**
  String get processingTranscription;

  /// No description provided for @preprocessingStatus.
  ///
  /// In en, this message translates to:
  /// **'Preprocessing: Transcoding and silence detection...'**
  String get preprocessingStatus;

  /// No description provided for @segmentsExtracted.
  ///
  /// In en, this message translates to:
  /// **'{count} segments extracted ({lang})'**
  String segmentsExtracted(int count, String lang);

  /// No description provided for @stepTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get stepTranslate;

  /// No description provided for @geminiApiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get geminiApiKey;

  /// No description provided for @enterApiKey.
  ///
  /// In en, this message translates to:
  /// **'Enter your API Key'**
  String get enterApiKey;

  /// No description provided for @aiProvider.
  ///
  /// In en, this message translates to:
  /// **'AI Provider'**
  String get aiProvider;

  /// No description provided for @geminiModel.
  ///
  /// In en, this message translates to:
  /// **'AI Model'**
  String get geminiModel;

  /// No description provided for @enterGeminiModel.
  ///
  /// In en, this message translates to:
  /// **'e.g., gemini-2.0-flash, gpt-4o'**
  String get enterGeminiModel;

  /// No description provided for @targetLanguage.
  ///
  /// In en, this message translates to:
  /// **'Target Language'**
  String get targetLanguage;

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// No description provided for @initializingTranslation.
  ///
  /// In en, this message translates to:
  /// **'Initializing translation...'**
  String get initializingTranslation;

  /// No description provided for @translatingProgress.
  ///
  /// In en, this message translates to:
  /// **'Translating subtitles ({completed}/{total})...'**
  String translatingProgress(int completed, int total);

  /// No description provided for @segmentsTranslated.
  ///
  /// In en, this message translates to:
  /// **'{count} segments translated to {lang}'**
  String segmentsTranslated(int count, String lang);

  /// No description provided for @stepPreviewExport.
  ///
  /// In en, this message translates to:
  /// **'Preview & Export'**
  String get stepPreviewExport;

  /// No description provided for @exportOriginal.
  ///
  /// In en, this message translates to:
  /// **'Export Original'**
  String get exportOriginal;

  /// No description provided for @exportTranslated.
  ///
  /// In en, this message translates to:
  /// **'Export Translated'**
  String get exportTranslated;

  /// No description provided for @exportBilingual.
  ///
  /// In en, this message translates to:
  /// **'Export Bilingual'**
  String get exportBilingual;

  /// No description provided for @noSubtitlesYet.
  ///
  /// In en, this message translates to:
  /// **'No subtitles yet'**
  String get noSubtitlesYet;

  /// No description provided for @completeTranscriptionFirst.
  ///
  /// In en, this message translates to:
  /// **'Complete the transcription step to see subtitles here'**
  String get completeTranscriptionFirst;

  /// No description provided for @exportedTo.
  ///
  /// In en, this message translates to:
  /// **'Exported to {path}'**
  String exportedTo(String path);

  /// No description provided for @exportSrt.
  ///
  /// In en, this message translates to:
  /// **'Export SRT'**
  String get exportSrt;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @apiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Paste your API key here'**
  String get apiKeyHint;

  /// No description provided for @getApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Get your API key from the selected AI provider\'s dashboard'**
  String get getApiKeyHint;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @batchSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Translate {count} subtitles per batch'**
  String batchSizeLabel(Object count);

  /// No description provided for @batchSizeHint.
  ///
  /// In en, this message translates to:
  /// **'More: Faster, better context. Less: More stable, but more API requests.'**
  String get batchSizeHint;

  /// No description provided for @recentProjects.
  ///
  /// In en, this message translates to:
  /// **'Recent Projects'**
  String get recentProjects;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @noProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects history'**
  String get noProjects;

  /// No description provided for @progressLabel.
  ///
  /// In en, this message translates to:
  /// **'Progress: {completed} / {total}'**
  String progressLabel(int completed, int total);

  /// No description provided for @detect.
  ///
  /// In en, this message translates to:
  /// **'Detect'**
  String get detect;

  /// No description provided for @clickDetectToFetchModels.
  ///
  /// In en, this message translates to:
  /// **'Please click \"Detect\" to fetch available models'**
  String get clickDetectToFetchModels;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
