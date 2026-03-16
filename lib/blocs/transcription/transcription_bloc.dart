import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import '../../services/whisper/whisper_service.dart';
import 'transcription_event.dart';
import 'transcription_state.dart';

/// BLoC managing the video transcription workflow.
///
/// No separate audio extraction step — WhisperController auto-converts
/// video files via the registered WhisperFFmpegConverter.
class TranscriptionBloc extends Bloc<TranscriptionEvent, TranscriptionState> {
  final WhisperService _whisperService;

  TranscriptionBloc({
    WhisperService? whisperService,
  })  : _whisperService = whisperService ?? WhisperService(),
        super(const TranscriptionInitial()) {
    on<SelectVideo>(_onSelectVideo);
    on<StartTranscription>(_onStartTranscription);
    on<ResetTranscription>(_onReset);
    on<LoadTranscriptionFromProject>(_onLoadTranscriptionFromProject);
  }

  void _onSelectVideo(
    SelectVideo event,
    Emitter<TranscriptionState> emit,
  ) {
    emit(VideoSelected(
      videoPath: event.videoPath,
      fileName: p.basename(event.videoPath),
    ));
  }

  Future<void> _onStartTranscription(
    StartTranscription event,
    Emitter<TranscriptionState> emit,
  ) async {
    final videoPath = _currentVideoPath;
    final fileName = _currentFileName;
    if (videoPath == null || fileName == null) return;

    try {
      // Step 1: Download model with progress
      emit(ModelDownloading(
        videoPath: videoPath,
        fileName: fileName,
        modelName: event.modelName,
        progress: 0,
      ));

      await _whisperService.loadModel(
        event.modelName,
        onDownloadProgress: (received, total) {
          if (!emit.isDone) {
            emit(ModelDownloading(
              videoPath: videoPath,
              fileName: fileName,
              modelName: event.modelName,
              progress: total > 0 ? received / total : -1,
            ));
          }
        },
      );

      // Step 2: Transcribe (video → auto-convert → whisper)
      // No separate audio extraction step needed — WhisperFFmpegConverter handles it
      emit(Transcribing(
        videoPath: videoPath,
        fileName: fileName,
        statusMessage: 'Processing and transcribing...',
      ));

      final result = await _whisperService.transcribe(
        videoPath, // Pass video file directly
        language: event.language ?? 'auto',
        onProgress: (progress) {
          if (!emit.isDone) {
            emit(Transcribing(
              videoPath: videoPath,
              fileName: fileName,
              statusMessage: 'Transcribing...',
              progress: progress,
            ));
          }
        },
      );

      emit(TranscriptionComplete(
        videoPath: videoPath,
        fileName: fileName,
        result: result,
      ));
    } catch (e) {
      emit(TranscriptionError(
        videoPath: videoPath,
        fileName: fileName,
        message: e.toString(),
      ));
    }
  }

  void _onReset(
    ResetTranscription event,
    Emitter<TranscriptionState> emit,
  ) {
    emit(const TranscriptionInitial());
  }

  void _onLoadTranscriptionFromProject(
    LoadTranscriptionFromProject event,
    Emitter<TranscriptionState> emit,
  ) {
    emit(TranscriptionComplete(
      videoPath: event.videoPath,
      fileName: event.fileName,
      result: event.result,
    ));
  }

  String? get _currentVideoPath {
    final s = state;
    if (s is VideoSelected) return s.videoPath;
    if (s is ModelDownloading) return s.videoPath;
    if (s is AudioExtracting) return s.videoPath;
    if (s is Transcribing) return s.videoPath;
    if (s is TranscriptionComplete) return s.videoPath;
    if (s is TranscriptionError) return s.videoPath;
    return null;
  }

  String? get _currentFileName {
    final s = state;
    if (s is VideoSelected) return s.fileName;
    if (s is ModelDownloading) return s.fileName;
    if (s is AudioExtracting) return s.fileName;
    if (s is Transcribing) return s.fileName;
    if (s is TranscriptionComplete) return s.fileName;
    if (s is TranscriptionError) return s.fileName;
    return null;
  }

  @override
  Future<void> close() async {
    await _whisperService.dispose();
    return super.close();
  }
}
