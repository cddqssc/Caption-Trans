// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Caption Trans';

  @override
  String get settings => '设置';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get close => '关闭';

  @override
  String get error => '错误';

  @override
  String get stepSelectVideo => '选择视频';

  @override
  String get clickToSelectVideo => '点击选择视频文件';

  @override
  String get supportedFormats => '支持 MP4、MKV、AVI、MOV、WebM 等格式';

  @override
  String get videoSelected => '已选择视频文件';

  @override
  String get changeFile => '更换文件';

  @override
  String get clear => '清除';

  @override
  String get stepExtractSubtitles => '提取字幕';

  @override
  String get whisperModel => '模型';

  @override
  String get sourceVideoLanguage => '源视频语言';

  @override
  String get sourceVideoLanguageHint => '选取源视频语言可以提高转录效率和准确率';

  @override
  String get diskUsage => '磁盘';

  @override
  String get memoryUsage => '内存';

  @override
  String get transcriptionQuality => '质量';

  @override
  String get qualityLow => '低';

  @override
  String get qualityBasic => '基础';

  @override
  String get qualityGood => '良好';

  @override
  String get qualityExcellent => '优秀';

  @override
  String get qualitySuperior => '极佳 (推荐)';

  @override
  String get qualityBest => '最好';

  @override
  String get extract => '提取';

  @override
  String get preparingRuntime => '正在准备运行时...';

  @override
  String get runtimeChecking => '正在检查运行时...';

  @override
  String get runtimeDownloading => '正在下载运行时包...';

  @override
  String get runtimeExtracting => '正在解压运行时包...';

  @override
  String get runtimeCreatingEnvironment => '正在创建 Python 环境...';

  @override
  String get runtimeInstallingDependencies => '正在安装依赖（首次安装需要较长时间）...';

  @override
  String get runtimeStartingSidecar => '正在启动运行时...';

  @override
  String get transcodingAudio => '正在将媒体转码为音频...';

  @override
  String get transcribingStatus => '正在转录...';

  @override
  String get transcriptionLoadingAudio => '正在加载音频...';

  @override
  String get transcriptionPreparingModel => '正在准备模型（首次运行若无缓存会下载）...';

  @override
  String get transcriptionRunning => '正在转录音频...';

  @override
  String get transcriptionAligning => '正在对齐时间戳...';

  @override
  String get transcriptionFinalizing => '正在整理转录结果...';

  @override
  String get extractingAudio => '正在从视频中提取音频...';

  @override
  String get processingTranscription => '字幕转录中...';

  @override
  String get preprocessingStatus => '预处理：转码和静音检测中...';

  @override
  String segmentsExtracted(int count, String lang) {
    return '已提取 $count 条字幕段 ($lang)';
  }

  @override
  String get stepTranslate => '翻译';

  @override
  String get geminiApiKey => 'API Key';

  @override
  String get enterApiKey => '输入您的 API Key';

  @override
  String get aiProvider => '大模型服务商';

  @override
  String get geminiModel => 'AI 模型';

  @override
  String get enterGeminiModel => '例如：gemini-2.0-flash, gpt-4o';

  @override
  String get targetLanguage => '目标语言';

  @override
  String get translate => '翻译';

  @override
  String get continueTranslation => '继续翻译';

  @override
  String retryFailedTranslations(int count) {
    return '重试失败 ($count)';
  }

  @override
  String get retranslate => '重新翻译';

  @override
  String get initializingTranslation => '正在初始化翻译...';

  @override
  String translatingProgress(int completed, int total) {
    return '正在翻译字幕 ($completed/$total)...';
  }

  @override
  String segmentsTranslated(int count, String lang) {
    return '已翻译 $count 条字幕为$lang';
  }

  @override
  String get stepPreviewExport => '预览和导出';

  @override
  String get exportOriginal => '导出原文';

  @override
  String get exportTranslated => '导出翻译';

  @override
  String get exportBilingual => '导出双语';

  @override
  String get noSubtitlesYet => '暂无字幕';

  @override
  String get completeTranscriptionFirst => '完成字幕提取步骤后，字幕将显示在此处';

  @override
  String exportedTo(String path) {
    return '已导出至 $path';
  }

  @override
  String get exportSrt => '导出 SRT';

  @override
  String get settingsTitle => '设置';

  @override
  String get downloadSourceTitle => '下载源';

  @override
  String get downloadSourceHint => '选择 WhisperX 用于下载运行时、依赖和模型的源配置。之后可在设置中修改。';

  @override
  String get downloadSourceSectionTitle => 'WhisperX 下载';

  @override
  String get downloadSourceSectionHint =>
      '用于 Python 运行时、pip 依赖、PyTorch wheels 和模型下载。';

  @override
  String get downloadSourcePromptTitle => '选择下载源';

  @override
  String get downloadSourcePromptMessage =>
      '首次下载 WhisperX 运行时、依赖和模型前，请先选择下载源。之后可在设置中修改。';

  @override
  String get downloadSourceGlobal => '国际源';

  @override
  String get downloadSourceGlobalDescription =>
      '使用官方 GitHub、PyPI、PyTorch 和 Hugging Face 源。更适合中国大陆以外网络环境。';

  @override
  String get downloadSourceChina => '中国大陆源';

  @override
  String get downloadSourceChinaDescription =>
      '优先使用中国大陆可用镜像下载运行时、PyPI、PyTorch 和 Hugging Face 模型。';

  @override
  String get downloadSourceUnset => '未选择';

  @override
  String get changeDownloadSource => '更改下载源';

  @override
  String get downloadSourceUpdated => '下载源已更新。';

  @override
  String get apiKeyHint => '粘贴您的 API Key';

  @override
  String get getApiKeyHint => '从所选服务商的开发者控制台获取 API Key';

  @override
  String get language => '界面语言';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get paste => '粘贴';

  @override
  String batchSizeLabel(Object count) {
    return '每次翻译 $count 条字幕';
  }

  @override
  String get batchSizeHint => '较多：更快、一致性好但易超时；较少：更稳但接口请求多';

  @override
  String get recentProjects => '最近项目';

  @override
  String get viewAll => '查看全部';

  @override
  String get noProjects => '暂无历史项目';

  @override
  String progressLabel(int completed, int total) {
    return '进度: $completed / $total';
  }

  @override
  String get detect => '检测';

  @override
  String get clickDetectToFetchModels => '请点击“检测”以获取可用模型';

  @override
  String get savedProvidersTitle => '已保存的服务商';

  @override
  String get savedProvidersEmpty => '暂无已保存的服务商';

  @override
  String get savedProvidersHint => 'API验证成功后自动保存到本地';

  @override
  String get appUpdate => '应用更新';

  @override
  String get currentVersion => '当前版本';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get checkingForUpdates => '正在检查更新...';

  @override
  String get updateAvailableTitle => '发现新版本';

  @override
  String updateAvailableMessage(String latest, String current) {
    return '发现新版本 $latest，当前版本为 $current。';
  }

  @override
  String get downloadUpdate => '下载更新';

  @override
  String alreadyLatestVersion(String version) {
    return '当前已是最新版本（$version）。';
  }

  @override
  String get updateCheckFailed => '检查更新失败。';

  @override
  String batchQueueFinished(int count) {
    return '队列处理完成（共 $count 个文件）。';
  }

  @override
  String autoExported(String path) {
    return '已自动导出：$path';
  }

  @override
  String autoExportFailed(int maxAttempts, String fileName) {
    return '自动导出失败，已重试 $maxAttempts 次：$fileName';
  }

  @override
  String get selectedFilesAlreadyInQueue => '所选文件已在队列中。';

  @override
  String batchQueueAdded(int count) {
    return '已添加 $count 个文件到队列。';
  }

  @override
  String batchQueueAddedEnableAuto(int count) {
    return '已添加 $count 个文件。开启自动提取后将开始队列处理。';
  }

  @override
  String batchQueueAddedWithDuplicates(int addedCount, int duplicateCount) {
    return '已添加 $addedCount 个文件，$duplicateCount 个重复任务已跳过。';
  }

  @override
  String get queueAutomationSettingsTitle => '队列自动化设置';

  @override
  String get removeQueueTask => '移除任务';

  @override
  String get cannotRemoveActiveQueueTask => '当前任务正在处理中，无法移除。';

  @override
  String queueTaskRemoved(String fileName) {
    return '已从队列移除：$fileName';
  }

  @override
  String get autoProcessExtractionQueueTitle => '自动处理提取队列';

  @override
  String get autoProcessExtractionQueueSubtitle =>
      '对已选择文件连续执行提取（每个文件最多重试 3 次）。';

  @override
  String get autoProcessTranslationQueueTitle => '自动处理翻译队列';

  @override
  String get autoProcessTranslationQueueSubtitle =>
      '翻译失败时自动重试并继续队列（每个文件最多重试 3 次）。';

  @override
  String maxRetriesPerStage(int maxRetries) {
    return '每阶段最大重试次数：$maxRetries';
  }

  @override
  String batchQueueTitle(int count) {
    return '批处理队列（$count）';
  }

  @override
  String get queueRunning => '运行中...';

  @override
  String get queueIdle => '空闲';

  @override
  String get queueStagePending => '待处理';

  @override
  String get queueStageExtracting => '提取中';

  @override
  String get queueStageExtractFailed => '提取失败';

  @override
  String get queueStageExtracted => '已提取';

  @override
  String get queueStageTranslating => '翻译中';

  @override
  String get queueStageTranslationFailed => '翻译失败';

  @override
  String get queueStageExporting => '导出中';

  @override
  String get queueStageExportFailed => '导出失败';

  @override
  String get queueStageCompleted => '已完成';

  @override
  String get queueStageSkipped => '已跳过';

  @override
  String get releaseNotes => '更新说明';
}
