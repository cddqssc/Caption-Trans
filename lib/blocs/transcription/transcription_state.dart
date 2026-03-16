import 'package:equatable/equatable.dart';
import '../../models/transcription_result.dart';

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

/// Model is being downloaded.
class ModelDownloading extends TranscriptionState {
  final String videoPath;
  final String fileName;
  final String modelName;
  final double progress;

  const ModelDownloading({
    required this.videoPath,
    required this.fileName,
    required this.modelName,
    required this.progress,
  });

  @override
  List<Object?> get props => [videoPath, fileName, modelName, progress];
}

/// Audio is being extracted from the video.
class AudioExtracting extends TranscriptionState {
  final String videoPath;
  final String fileName;

  const AudioExtracting({required this.videoPath, required this.fileName});

  @override
  List<Object?> get props => [videoPath, fileName];
}

/// Whisper is transcribing the audio.
class Transcribing extends TranscriptionState {
  final String videoPath;
  final String fileName;
  final String statusMessage;
  final int progress;
  const Transcribing({
    required this.videoPath,
    required this.fileName,
    this.statusMessage = 'Transcribing...',
    this.progress = 0,
  });

  @override
  List<Object?> get props => [videoPath, fileName, statusMessage, progress];
}

/// Transcription completed successfully.
class TranscriptionComplete extends TranscriptionState {
  final String videoPath;
  final String fileName;
  final TranscriptionResult result;

  const TranscriptionComplete({
    required this.videoPath,
    required this.fileName,
    required this.result,
  });

  @override
  List<Object?> get props => [videoPath, fileName, result];
}

/// Transcription failed.
class TranscriptionError extends TranscriptionState {
  final String videoPath;
  final String fileName;
  final String message;

  const TranscriptionError({
    required this.videoPath,
    required this.fileName,
    required this.message,
  });

  @override
  List<Object?> get props => [videoPath, fileName, message];
}
