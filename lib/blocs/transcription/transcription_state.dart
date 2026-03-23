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

enum ModelPreparingPhase {
  checkingModel,
  downloadingModel,
  extractingModel,
  loadingModel,
}

/// Model is being downloaded or loaded.
class ModelPreparing extends TranscriptionState {
  final String videoPath;
  final String fileName;
  final ModelPreparingPhase phase;
  final double? progress;

  const ModelPreparing({
    required this.videoPath,
    required this.fileName,
    this.phase = ModelPreparingPhase.checkingModel,
    this.progress,
  });

  @override
  List<Object?> get props => [videoPath, fileName, phase, progress];
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

/// Whisper is transcribing.
enum TranscribingPhase {
  loadingAudio,
  transcribing,
  finalizing,
}

class Transcribing extends TranscriptionState {
  final String videoPath;
  final String fileName;
  final TranscribingPhase phase;
  final String? statusDetail;
  final WhisperRuntimeInfo? runtimeInfo;

  const Transcribing({
    required this.videoPath,
    required this.fileName,
    this.phase = TranscribingPhase.transcribing,
    this.statusDetail,
    this.runtimeInfo,
  });

  @override
  List<Object?> get props => [
    videoPath,
    fileName,
    phase,
    statusDetail,
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
  final WhisperRuntimeInfo? runtimeInfo;

  const TranscriptionError({
    required this.videoPath,
    required this.fileName,
    required this.message,
    this.runtimeInfo,
  });

  @override
  List<Object?> get props => [videoPath, fileName, message, runtimeInfo];
}
