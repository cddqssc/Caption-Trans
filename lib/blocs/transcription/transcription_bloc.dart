import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../models/whisper_runtime_info.dart';
import '../../services/whisper/whisper_service.dart';
import 'transcription_event.dart';
import 'transcription_state.dart';

/// BLoC managing the transcription workflow.
class TranscriptionBloc extends Bloc<TranscriptionEvent, TranscriptionState> {
  static final RegExp _ansiEscapePattern = RegExp(
    r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])',
  );

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
      // 1) Prepare runtime resources.
      // Only the download phase has determinate progress; install/start phases
      // stay in RuntimePreparing with translated status text.
      emit(
        RuntimePreparing(
          videoPath: videoPath,
          fileName: fileName,
          phase: RuntimePreparingPhase.checkingRuntime,
        ),
      );
      await _whisperService.downloadModel(
        event.modelName,
        onPreparationState: (phase, progress) {
          if (emit.isDone) return;
          emit(
            RuntimePreparing(
              videoPath: videoPath,
              fileName: fileName,
              phase: _runtimePreparingPhaseFromCode(phase),
              progress: progress,
              runtimeInfo: runtimeInfo,
            ),
          );
        },
      );

      // 2) Select model for this run (actual model load happens in transcribe).
      await _whisperService.loadModel(event.modelName);
      runtimeInfo = await _whisperService.inspectRuntime(
        modelName: event.modelName,
      );

      // 3) Transcode media to WAV (no progress)
      emit(
        AudioTranscoding(
          videoPath: videoPath,
          fileName: fileName,
          runtimeInfo: runtimeInfo,
        ),
      );
      wavPath = await _whisperService.transcodeToWav(videoPath);

      // 4) Transcribe with explicit sidecar phases + runtime logs.
      TranscribingPhase currentPhase = TranscribingPhase.preparingModel;
      String? currentDetail;
      void emitTranscribingState({
        required TranscribingPhase phase,
        String? detail,
        WhisperRuntimeInfo? nextRuntimeInfo,
      }) {
        final String? normalized = detail == null
            ? null
            : _normalizeLogLine(detail);
        final WhisperRuntimeInfo? resolvedRuntimeInfo =
            nextRuntimeInfo ?? runtimeInfo;
        if (currentPhase == phase &&
            currentDetail == normalized &&
            runtimeInfo == resolvedRuntimeInfo) {
          return;
        }
        currentPhase = phase;
        currentDetail = normalized;
        runtimeInfo = resolvedRuntimeInfo;
        if (emit.isDone) return;
        emit(
          Transcribing(
            videoPath: videoPath,
            fileName: fileName,
            phase: phase,
            statusDetail: normalized,
            runtimeInfo: runtimeInfo,
          ),
        );
      }

      emit(
        Transcribing(
          videoPath: videoPath,
          fileName: fileName,
          phase: currentPhase,
          runtimeInfo: runtimeInfo,
        ),
      );
      final result = await _whisperService.transcribeWav(
        wavPath,
        language: event.language ?? 'auto',
        onRuntimeInfo: (info) {
          emitTranscribingState(
            phase: currentPhase,
            detail: currentDetail,
            nextRuntimeInfo: info,
          );
        },
        onStatus: (status, detail) {
          final TranscribingPhase phase = _phaseFromWorkerStatus(status);
          emitTranscribingState(phase: phase, detail: detail);
        },
        onLog: (line) {
          final String? normalized = _normalizeLogLine(line);
          if (normalized == null) return;
          final TranscribingPhase phase =
              _phaseFromLogLine(normalized) ?? currentPhase;
          emitTranscribingState(phase: phase, detail: normalized);
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

  String? _normalizeLogLine(String line) {
    final String trimmed = line.replaceAll(_ansiEscapePattern, '').trim();
    if (trimmed.isEmpty) return null;
    // WhisperX/PyTorch logs can be very long; keep status concise in UI.
    return trimmed.length > 140 ? '${trimmed.substring(0, 140)}...' : trimmed;
  }

  RuntimePreparingPhase _runtimePreparingPhaseFromCode(String phase) {
    switch (phase) {
      case 'downloading_runtime':
        return RuntimePreparingPhase.downloadingRuntime;
      case 'extracting_runtime':
        return RuntimePreparingPhase.extractingRuntime;
      case 'creating_environment':
        return RuntimePreparingPhase.creatingEnvironment;
      case 'installing_dependencies':
        return RuntimePreparingPhase.installingDependencies;
      case 'starting_sidecar':
        return RuntimePreparingPhase.startingSidecar;
      case 'checking_runtime':
      default:
        return RuntimePreparingPhase.checkingRuntime;
    }
  }

  TranscribingPhase _phaseFromWorkerStatus(String status) {
    switch (status) {
      case 'loading_audio':
        return TranscribingPhase.loadingAudio;
      case 'preparing_model':
        return TranscribingPhase.preparingModel;
      case 'transcribing':
        return TranscribingPhase.transcribing;
      case 'aligning':
        return TranscribingPhase.aligning;
      case 'finalizing':
        return TranscribingPhase.finalizing;
      default:
        return TranscribingPhase.transcribing;
    }
  }

  TranscribingPhase? _phaseFromLogLine(String line) {
    final String lower = line.toLowerCase();
    if (lower.contains('download')) {
      return TranscribingPhase.preparingModel;
    }
    if (lower.contains('align')) {
      return TranscribingPhase.aligning;
    }
    if (lower.contains('transcrib')) {
      return TranscribingPhase.transcribing;
    }
    if (lower.contains('model') || lower.contains('loading')) {
      return TranscribingPhase.preparingModel;
    }
    if (lower.contains('audio') || lower.contains('wav')) {
      return TranscribingPhase.loadingAudio;
    }
    return null;
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
    if (s is RuntimePreparing) return s.videoPath;
    if (s is AudioTranscoding) return s.videoPath;
    if (s is Transcribing) return s.videoPath;
    if (s is TranscriptionComplete) return s.videoPath;
    if (s is TranscriptionError) return s.videoPath;
    return null;
  }

  String? get _currentFileName {
    final s = state;
    if (s is VideoSelected) return s.fileName;
    if (s is RuntimePreparing) return s.fileName;
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
