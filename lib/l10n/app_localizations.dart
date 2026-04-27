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
  /// **'Model'**
  String get whisperModel;

  /// No description provided for @sourceVideoLanguage.
  ///
  /// In en, this message translates to:
  /// **'Source Video Language'**
  String get sourceVideoLanguage;

  /// No description provided for @sourceVideoLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Selecting source video language can improve transcription efficiency and accuracy.'**
  String get sourceVideoLanguageHint;

  /// No description provided for @diskUsage.
  ///
  /// In en, this message translates to:
  /// **'Disk'**
  String get diskUsage;

  /// No description provided for @memoryUsage.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get memoryUsage;

  /// No description provided for @transcriptionQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
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

  /// No description provided for @preparingRuntime.
  ///
  /// In en, this message translates to:
  /// **'Preparing runtime...'**
  String get preparingRuntime;

  /// No description provided for @runtimeChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking runtime...'**
  String get runtimeChecking;

  /// No description provided for @runtimeDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading runtime package...'**
  String get runtimeDownloading;

  /// No description provided for @runtimeExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting runtime package...'**
  String get runtimeExtracting;

  /// No description provided for @runtimeCreatingEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Creating Python environment...'**
  String get runtimeCreatingEnvironment;

  /// No description provided for @runtimeInstallingDependencies.
  ///
  /// In en, this message translates to:
  /// **'Installing dependencies (first run may take a while)...'**
  String get runtimeInstallingDependencies;

  /// No description provided for @runtimeStartingSidecar.
  ///
  /// In en, this message translates to:
  /// **'Starting runtime...'**
  String get runtimeStartingSidecar;

  /// No description provided for @transcodingAudio.
  ///
  /// In en, this message translates to:
  /// **'Transcoding media to audio...'**
  String get transcodingAudio;

  /// No description provided for @transcribingStatus.
  ///
  /// In en, this message translates to:
  /// **'Transcribing...'**
  String get transcribingStatus;

  /// No description provided for @transcriptionLoadingAudio.
  ///
  /// In en, this message translates to:
  /// **'Loading audio...'**
  String get transcriptionLoadingAudio;

  /// No description provided for @transcriptionPreparingModel.
  ///
  /// In en, this message translates to:
  /// **'Preparing model (download on first run if needed)...'**
  String get transcriptionPreparingModel;

  /// No description provided for @transcriptionRunning.
  ///
  /// In en, this message translates to:
  /// **'Transcribing audio...'**
  String get transcriptionRunning;

  /// No description provided for @transcriptionAligning.
  ///
  /// In en, this message translates to:
  /// **'Aligning timestamps...'**
  String get transcriptionAligning;

  /// No description provided for @transcriptionFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Finalizing transcription result...'**
  String get transcriptionFinalizing;

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

  /// No description provided for @continueTranslation.
  ///
  /// In en, this message translates to:
  /// **'Continue Translation'**
  String get continueTranslation;

  /// No description provided for @retryFailedTranslations.
  ///
  /// In en, this message translates to:
  /// **'Retry Failed ({count})'**
  String retryFailedTranslations(int count);

  /// No description provided for @retranslate.
  ///
  /// In en, this message translates to:
  /// **'Retranslate'**
  String get retranslate;

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

  /// No description provided for @downloadSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Download source'**
  String get downloadSourceTitle;

  /// No description provided for @downloadSourceHint.
  ///
  /// In en, this message translates to:
  /// **'Choose which source profile WhisperX should use for runtime, dependency, and model downloads. You can change it later in Settings.'**
  String get downloadSourceHint;

  /// No description provided for @downloadSourceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'WhisperX downloads'**
  String get downloadSourceSectionTitle;

  /// No description provided for @downloadSourceSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Applies to Python runtime, pip dependencies, PyTorch wheels, and model downloads.'**
  String get downloadSourceSectionHint;

  /// No description provided for @downloadSourcePromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose download source'**
  String get downloadSourcePromptTitle;

  /// No description provided for @downloadSourcePromptMessage.
  ///
  /// In en, this message translates to:
  /// **'Before WhisperX downloads runtime files, dependencies, and models for the first time, choose which source profile to use. You can change this later in Settings.'**
  String get downloadSourcePromptMessage;

  /// No description provided for @downloadSourceGlobal.
  ///
  /// In en, this message translates to:
  /// **'International source'**
  String get downloadSourceGlobal;

  /// No description provided for @downloadSourceGlobalDescription.
  ///
  /// In en, this message translates to:
  /// **'Use official GitHub, PyPI, PyTorch, and Hugging Face sources. Recommended outside mainland China.'**
  String get downloadSourceGlobalDescription;

  /// No description provided for @downloadSourceChina.
  ///
  /// In en, this message translates to:
  /// **'Mainland China source'**
  String get downloadSourceChina;

  /// No description provided for @downloadSourceChinaDescription.
  ///
  /// In en, this message translates to:
  /// **'Use mainland mirrors when available for runtime, PyPI, PyTorch, and Hugging Face downloads.'**
  String get downloadSourceChinaDescription;

  /// No description provided for @downloadSourceUnset.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get downloadSourceUnset;

  /// No description provided for @changeDownloadSource.
  ///
  /// In en, this message translates to:
  /// **'Change download source'**
  String get changeDownloadSource;

  /// No description provided for @downloadSourceUpdated.
  ///
  /// In en, this message translates to:
  /// **'Download source updated.'**
  String get downloadSourceUpdated;

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

  /// No description provided for @savedProvidersTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved Providers'**
  String get savedProvidersTitle;

  /// No description provided for @savedProvidersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved providers'**
  String get savedProvidersEmpty;

  /// No description provided for @savedProvidersHint.
  ///
  /// In en, this message translates to:
  /// **'Automatically saved locally after API verification succeeds'**
  String get savedProvidersHint;

  /// No description provided for @appUpdate.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get appUpdate;

  /// No description provided for @currentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get currentVersion;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @checkingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get checkingForUpdates;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Version {latest} is available. You are currently on {current}.'**
  String updateAvailableMessage(String latest, String current);

  /// No description provided for @downloadUpdate.
  ///
  /// In en, this message translates to:
  /// **'Download update'**
  String get downloadUpdate;

  /// No description provided for @alreadyLatestVersion.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the latest version ({version}).'**
  String alreadyLatestVersion(String version);

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to check for updates.'**
  String get updateCheckFailed;

  /// No description provided for @batchQueueFinished.
  ///
  /// In en, this message translates to:
  /// **'Batch queue finished ({count} files).'**
  String batchQueueFinished(int count);

  /// No description provided for @autoExported.
  ///
  /// In en, this message translates to:
  /// **'Auto exported: {path}'**
  String autoExported(String path);

  /// No description provided for @autoExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Auto export failed after {maxAttempts} attempts: {fileName}'**
  String autoExportFailed(int maxAttempts, String fileName);

  /// No description provided for @selectedFilesAlreadyInQueue.
  ///
  /// In en, this message translates to:
  /// **'Selected files are already in queue.'**
  String get selectedFilesAlreadyInQueue;

  /// No description provided for @batchQueueAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {count} file(s) to queue.'**
  String batchQueueAdded(int count);

  /// No description provided for @batchQueueAddedEnableAuto.
  ///
  /// In en, this message translates to:
  /// **'Added {count} file(s). Enable auto extraction to process queue.'**
  String batchQueueAddedEnableAuto(int count);

  /// No description provided for @batchQueueAddedWithDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Added {addedCount} file(s), {duplicateCount} duplicate task(s) were skipped.'**
  String batchQueueAddedWithDuplicates(int addedCount, int duplicateCount);

  /// No description provided for @queueAutomationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Queue automation settings'**
  String get queueAutomationSettingsTitle;

  /// No description provided for @removeQueueTask.
  ///
  /// In en, this message translates to:
  /// **'Remove task'**
  String get removeQueueTask;

  /// No description provided for @cannotRemoveActiveQueueTask.
  ///
  /// In en, this message translates to:
  /// **'Cannot remove the task currently being processed.'**
  String get cannotRemoveActiveQueueTask;

  /// No description provided for @queueTaskRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from queue: {fileName}'**
  String queueTaskRemoved(String fileName);

  /// No description provided for @autoProcessExtractionQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto process extraction queue'**
  String get autoProcessExtractionQueueTitle;

  /// No description provided for @autoProcessExtractionQueueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Run extraction continuously for selected files (max 3 attempts per file).'**
  String get autoProcessExtractionQueueSubtitle;

  /// No description provided for @autoProcessTranslationQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto process translation queue'**
  String get autoProcessTranslationQueueTitle;

  /// No description provided for @autoProcessTranslationQueueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Retry translation errors automatically and continue queue (max 3 attempts per file).'**
  String get autoProcessTranslationQueueSubtitle;

  /// No description provided for @maxRetriesPerStage.
  ///
  /// In en, this message translates to:
  /// **'Max retries per stage: {maxRetries}'**
  String maxRetriesPerStage(int maxRetries);

  /// No description provided for @batchQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch Queue ({count})'**
  String batchQueueTitle(int count);

  /// No description provided for @queueRunning.
  ///
  /// In en, this message translates to:
  /// **'Running...'**
  String get queueRunning;

  /// No description provided for @queueIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get queueIdle;

  /// No description provided for @queueStagePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get queueStagePending;

  /// No description provided for @queueStageExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting'**
  String get queueStageExtracting;

  /// No description provided for @queueStageExtractFailed.
  ///
  /// In en, this message translates to:
  /// **'Extract Failed'**
  String get queueStageExtractFailed;

  /// No description provided for @queueStageExtracted.
  ///
  /// In en, this message translates to:
  /// **'Extracted'**
  String get queueStageExtracted;

  /// No description provided for @queueStageTranslating.
  ///
  /// In en, this message translates to:
  /// **'Translating'**
  String get queueStageTranslating;

  /// No description provided for @queueStageTranslationFailed.
  ///
  /// In en, this message translates to:
  /// **'Translation Failed'**
  String get queueStageTranslationFailed;

  /// No description provided for @queueStageExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting'**
  String get queueStageExporting;

  /// No description provided for @queueStageExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export Failed'**
  String get queueStageExportFailed;

  /// No description provided for @queueStageCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get queueStageCompleted;

  /// No description provided for @queueStageSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get queueStageSkipped;

  /// No description provided for @releaseNotes.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get releaseNotes;
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
