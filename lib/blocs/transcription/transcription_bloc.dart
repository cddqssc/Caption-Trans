import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../models/whisper_runtime_info.dart';
import '../../services/whisper/whisper_service.dart';
import 'transcription_event.dart';
import 'transcription_state.dart';

/// BLoC managing the transcription workflow.
class TranscriptionBloc extends Bloc<TranscriptionEvent, TranscriptionState> {
  final WhisperService _whisperService;

  TranscriptionBloc({WhisperService? whisperService})
    : _whisperService = whisperService ?? WhisperService(),
      super(const TranscriptionInitial()) {
    on<SelectVideo>(_onSelectVideo);
    on<StartTranscription>(_onStartTranscription);
    on<ResetTranscription>(_onReset);
    on<LoadTranscriptionFromProject>(_onLoadTranscriptionFromProject);
  }

  void _onSelectVideo(SelectVideo event, Emitter<TranscriptionState> emit) {
    emit(
      VideoSelected(
        videoPath: event.videoPath,
        fileName: p.basename(event.videoPath),
      ),
    );
  }

  Future<void> _onStartTranscription(
    StartTranscription event,
    Emitter<TranscriptionState> emit,
  ) async {
    final String? videoPath = _currentVideoPath;
    final String? fileName = _currentFileName;
    if (videoPath == null || fileName == null) return;

    String wavPath = videoPath;
    WhisperRuntimeInfo? runtimeInfo;
    try {
      // 1) Download model if needed.
      emit(
        ModelPreparing(
          videoPath: videoPath,
          fileName: fileName,
          phase: ModelPreparingPhase.checkingModel,
        ),
      );
      await _whisperService.downloadModel(
        event.modelName,
        onPreparationState: (phase, progress) {
          if (emit.isDone) return;
          emit(
            ModelPreparing(
              videoPath: videoPath,
              fileName: fileName,
              phase: _modelPreparingPhaseFromCode(phase),
              progress: progress,
            ),
          );
        },
      );

      // 2) Load model.
      emit(
        ModelPreparing(
          videoPath: videoPath,
          fileName: fileName,
          phase: ModelPreparingPhase.loadingModel,
        ),
      );
      await _whisperService.loadModel(event.modelName, language: event.language);
      runtimeInfo = _whisperService.inspectRuntime(
        modelName: event.modelName,
      );

      // 3) Transcode media to WAV.
      emit(
        AudioTranscoding(
          videoPath: videoPath,
          fileName: fileName,
          runtimeInfo: runtimeInfo,
        ),
      );
      wavPath = await _whisperService.transcodeToWav(videoPath);

      // 4) Transcribe.
      emit(
        Transcribing(
          videoPath: videoPath,
          fileName: fileName,
          phase: TranscribingPhase.transcribing,
          runtimeInfo: runtimeInfo,
        ),
      );
      final result = await _whisperService.transcribeWav(
        wavPath,
        language: event.language ?? 'auto',
        onRuntimeInfo: (info) {
          runtimeInfo = info;
        },
        onStatus: (status, detail) {
          if (emit.isDone) return;
          final TranscribingPhase phase = _phaseFromStatus(status);
          emit(
            Transcribing(
              videoPath: videoPath,
              fileName: fileName,
              phase: phase,
              statusDetail: detail,
              runtimeInfo: runtimeInfo,
            ),
          );
        },
      );

      emit(
        TranscriptionComplete(
          videoPath: videoPath,
          fileName: fileName,
          result: result,
          runtimeInfo: runtimeInfo,
        ),
      );
    } catch (e) {
      emit(
        TranscriptionError(
          videoPath: videoPath,
          fileName: fileName,
          message: e.toString(),
          runtimeInfo: runtimeInfo,
        ),
      );
    } finally {
      await _whisperService.cleanupTempWav(
        wavPath,
        originalMediaPath: videoPath,
      );
    }
  }

  ModelPreparingPhase _modelPreparingPhaseFromCode(String phase) {
    switch (phase) {
      case 'downloading_model':
        return ModelPreparingPhase.downloadingModel;
      case 'extracting_model':
        return ModelPreparingPhase.extractingModel;
      case 'model_ready':
        return ModelPreparingPhase.loadingModel;
      case 'checking_model':
      default:
        return ModelPreparingPhase.checkingModel;
    }
  }

  TranscribingPhase _phaseFromStatus(String status) {
    switch (status) {
      case 'loading_audio':
        return TranscribingPhase.loadingAudio;
      case 'transcribing':
        return TranscribingPhase.transcribing;
      case 'finalizing':
        return TranscribingPhase.finalizing;
      default:
        return TranscribingPhase.transcribing;
    }
  }

  void _onReset(ResetTranscription event, Emitter<TranscriptionState> emit) {
    emit(const TranscriptionInitial());
  }

  void _onLoadTranscriptionFromProject(
    LoadTranscriptionFromProject event,
    Emitter<TranscriptionState> emit,
  ) {
    emit(
      TranscriptionComplete(
        videoPath: event.videoPath,
        fileName: event.fileName,
        result: event.result,
      ),
    );
  }

  String? get _currentVideoPath {
    final s = state;
    if (s is VideoSelected) return s.videoPath;
    if (s is ModelPreparing) return s.videoPath;
    if (s is AudioTranscoding) return s.videoPath;
    if (s is Transcribing) return s.videoPath;
    if (s is TranscriptionComplete) return s.videoPath;
    if (s is TranscriptionError) return s.videoPath;
    return null;
  }

  String? get _currentFileName {
    final s = state;
    if (s is VideoSelected) return s.fileName;
    if (s is ModelPreparing) return s.fileName;
    if (s is AudioTranscoding) return s.fileName;
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
