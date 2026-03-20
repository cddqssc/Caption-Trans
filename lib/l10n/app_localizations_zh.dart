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
  String get whisperModel => 'Whisper 模型';

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
  String get preparingRuntime => '正在准备 WhisperX 运行时...';

  @override
  String get runtimeChecking => '正在检查 WhisperX 运行时...';

  @override
  String get runtimeDownloading => '正在下载运行时包...';

  @override
  String get runtimeExtracting => '正在解压运行时包...';

  @override
  String get runtimeCreatingEnvironment => '正在创建 Python 环境...';

  @override
  String get runtimeInstallingDependencies => '正在安装 WhisperX 依赖...';

  @override
  String get runtimeStartingSidecar => '正在启动 WhisperX 侧车...';

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
  String get savedProvidersHint => 'API验证成功后自会动保存到本地';
}
