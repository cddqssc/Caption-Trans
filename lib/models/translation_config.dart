import 'package:equatable/equatable.dart';

/// Configuration for the translation process.
class TranslationConfig extends Equatable {
  final String providerId;
  final String apiKey;
  final String baseUrl;
  final String? model;
  final String sourceLanguage;
  final String targetLanguage;

  /// Number of subtitle segments per translation batch.
  final int batchSize;

  /// Number of context lines from adjacent batches.
  final int contextOverlap;

  const TranslationConfig({
    required this.providerId,
    required this.apiKey,
    required this.baseUrl,
    this.model,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.batchSize = 15,
    this.contextOverlap = 3,
  });

  TranslationConfig copyWith({
    String? providerId,
    String? apiKey,
    String? baseUrl,
    String? model,
    String? sourceLanguage,
    String? targetLanguage,
    int? batchSize,
    int? contextOverlap,
  }) {
    return TranslationConfig(
      providerId: providerId ?? this.providerId,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      batchSize: batchSize ?? this.batchSize,
      contextOverlap: contextOverlap ?? this.contextOverlap,
    );
  }

  factory TranslationConfig.fromJson(Map<String, dynamic> json) {
    return TranslationConfig(
      providerId: json['providerId'] as String,
      apiKey: json['apiKey'] as String,
      baseUrl: json['baseUrl'] as String,
      model: json['model'] as String?,
      sourceLanguage: json['sourceLanguage'] as String,
      targetLanguage: json['targetLanguage'] as String,
      batchSize: json['batchSize'] as int? ?? 15,
      contextOverlap: json['contextOverlap'] as int? ?? 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'providerId': providerId,
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'model': model,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'batchSize': batchSize,
      'contextOverlap': contextOverlap,
    };
  }

  @override
  List<Object?> get props => [
    providerId,
    apiKey,
    baseUrl,
    model,
    sourceLanguage,
    targetLanguage,
    batchSize,
    contextOverlap,
  ];
}
