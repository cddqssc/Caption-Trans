import 'package:equatable/equatable.dart';
import 'transcription_result.dart';
import 'translation_config.dart';

/// Represents a transcription/translation project.
class Project extends Equatable {
  final String id;
  final String name;
  final String videoPath;
  final String sourceVideoLanguage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TranscriptionResult transcription;
  final TranslationConfig? translationConfig;

  const Project({
    required this.id,
    required this.name,
    required this.videoPath,
    required this.sourceVideoLanguage,
    required this.createdAt,
    required this.updatedAt,
    required this.transcription,
    this.translationConfig,
  });

  Project copyWith({
    String? id,
    String? name,
    String? videoPath,
    String? sourceVideoLanguage,
    DateTime? createdAt,
    DateTime? updatedAt,
    TranscriptionResult? transcription,
    TranslationConfig? translationConfig,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      videoPath: videoPath ?? this.videoPath,
      sourceVideoLanguage: sourceVideoLanguage ?? this.sourceVideoLanguage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      transcription: transcription ?? this.transcription,
      translationConfig: translationConfig ?? this.translationConfig,
    );
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      videoPath: json['videoPath'] as String,
      sourceVideoLanguage:
          (json['sourceVideoLanguage'] as String?)?.trim().isNotEmpty == true
          ? json['sourceVideoLanguage'] as String
          : 'en',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      transcription: TranscriptionResult.fromJson(
        json['transcription'] as Map<String, dynamic>,
      ),
      translationConfig: json['translationConfig'] != null
          ? TranslationConfig.fromJson(
              json['translationConfig'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'videoPath': videoPath,
      'sourceVideoLanguage': sourceVideoLanguage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'transcription': transcription.toJson(),
      'translationConfig': translationConfig?.toJson(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    videoPath,
    sourceVideoLanguage,
    createdAt,
    updatedAt,
    transcription,
    translationConfig,
  ];
}
