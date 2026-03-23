import 'package:equatable/equatable.dart';
import '../../models/transcription_result.dart';
import '../../models/whisper_runtime_info.dart';

/// States for the TranscriptionBloc.
abstract class TranscriptionState extends Equatable {
  const TranscriptionState();

  @override
  List<Object?> get props => [];
}

/// Initial state — no video selected.
class TranscriptionInitial extends TranscriptionState {
  const TranscriptionInitial();
}

/// A video file has been selected.
class VideoSelected extends TranscriptionState {
  final String videoPath;
  final String fileName;

  const VideoSelected({required this.videoPath, required this.fileName});

  @override
  List<Object?> get props => [videoPath, fileName];
}

enum RuntimePreparingPhase {
  checkingRuntime,
  downloadingRuntime,
  extractingRuntime,
  creatingEnvironment,
  installingDependencies,
  startingSidecar,
}

/// Sidecar runtime assets are being prepared/downloaded.
class RuntimePreparing extends TranscriptionState {
  final String videoPath;
  final String fileName;
  final RuntimePreparingPhase phase;
  final double? progress;
  final List<String> logLines;
  final WhisperRuntimeInfo? runtimeInfo;

  const RuntimePreparing({
    required this.videoPath,
    required this.fileName,
    this.phase = RuntimePreparingPhase.checkingRuntime,
    this.progress,
    this.logLines = const <String>[],
    this.runtimeInfo,
  });

  @override
  List<Object?> get props => [
    videoPath,
    fileName,
    phase,
    progress,
    logLines,
    runtimeInfo,
  ];
}

/// Media is being transcoded to WAV.
class AudioTranscoding extends TranscriptionState {
  final String videoPath;
  final String fileName;
  final WhisperRuntimeInfo? runtimeInfo;

  const AudioTranscoding({
    required this.videoPath,
    required this.fileName,
    this.runtimeInfo,
  });

  @override
  List<Object?> get props => [videoPath, fileName, runtimeInfo];
}

/// WhisperX is transcribing.
enum TranscribingPhase {
  loadingAudio,
  preparingModel,
  transcribing,
  aligning,
  finalizing,
}

class Transcribing extends TranscriptionState {
  final String videoPath;
  final String fileName;
  final TranscribingPhase phase;
  final String? statusDetail;
  final List<String> logLines;
  final WhisperRuntimeInfo? runtimeInfo;

  const Transcribing({
    required this.videoPath,
    required this.fileName,
    this.phase = TranscribingPhase.transcribing,
    this.statusDetail,
    this.logLines = const <String>[],
    this.runtimeInfo,
  });

  @override
  List<Object?> get props => [
    videoPath,
    fileName,
    phase,
    statusDetail,
    logLines,
    runtimeInfo,
  ];
}

/// Transcription completed successfully.
class TranscriptionComplete extends TranscriptionState {
  final String videoPath;
  final String fileName;
  final TranscriptionResult result;
  final WhisperRuntimeInfo? runtimeInfo;

  const TranscriptionComplete({
    required this.videoPath,
    required this.fileName,
    required this.result,
    this.runtimeInfo,
  });

  @override
  List<Object?> get props => [videoPath, fileName, result, runtimeInfo];
}

/// Transcription failed.
class TranscriptionError extends TranscriptionState {
  final String videoPath;
  final String fileName;
  final String message;
  final List<String> logLines;
  final WhisperRuntimeInfo? runtimeInfo;

  const TranscriptionError({
    required this.videoPath,
    required this.fileName,
    required this.message,
    this.logLines = const <String>[],
    this.runtimeInfo,
  });

  @override
  List<Object?> get props => [
    videoPath,
    fileName,
    message,
    logLines,
    runtimeInfo,
  ];
}
