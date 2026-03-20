import 'dart:convert';

import 'package:http/http.dart' as http;

import 'translation_provider.dart';

/// LLM implementation of [TranslationProvider] using the standard OpenAI API.
class LlmProvider implements TranslationProvider {
  static const _defaultBaseUrl = 'https://api.openai.com/v1';
  static const _defaultModel = 'gpt-4o';

  final String providerId;
  final http.Client Function() _clientFactory;

  String? _apiKey;
  String? _baseUrl;
  http.Client? _httpClient;

  LlmProvider({required this.providerId, http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  @override
  String get name => providerId;

  void _ensureClient(String apiKey, String? baseUrl) {
    if (_apiKey != apiKey || _baseUrl != baseUrl || _httpClient == null) {
      _apiKey = apiKey;
      _baseUrl = baseUrl;
      _httpClient?.close();
      _httpClient = _clientFactory();
    }
  }

  @override
  Future<List<String>> translateBatch({
    required List<String> texts,
    required String sourceLanguage,
    required String targetLanguage,
    String? model,
    List<String> contextBefore = const [],
    List<String> contextAfter = const [],
    Map<String, String> glossary = const {},
    void Function(int completed, int total)? onProgress,
    Future<void>? abortTrigger,
  }) async {
    if (_apiKey == null) {
      throw StateError('API key not configured. Call validateApiKey first.');
    }

    final prompt = _buildTranslationPrompt(
      texts: texts,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      contextBefore: contextBefore,
      contextAfter: contextAfter,
      glossary: glossary,
    );

    onProgress?.call(0, texts.length);

    final response = await _createChatCompletion(
      apiKey: _apiKey!,
      baseUrl: _baseUrl,
      model: model ?? _defaultModel,
      prompt: prompt,
      abortTrigger: abortTrigger,
    );

    onProgress?.call(texts.length, texts.length);

    return _parseTranslationResponse(
      response.text ?? '',
      texts.length,
      response.finishReason,
    );
  }

  @override
  Future<String> buildContextSummary({
    required List<String> allTexts,
    required String sourceLanguage,
    required String targetLanguage,
    String? model,
    Future<void>? abortTrigger,
  }) async {
    if (_apiKey == null) {
      throw StateError('API key not configured. Call validateApiKey first.');
    }
    if (allTexts.isEmpty) return '';

    final sampleSize = allTexts.length > 50 ? 50 : allTexts.length;
    final step = allTexts.length ~/ sampleSize;
    if (step == 0) return '';

    final sample = <String>[];
    for (
      var i = 0;
      i < allTexts.length && sample.length < sampleSize;
      i += step
    ) {
      sample.add(allTexts[i]);
    }

    final prompt =
        '''
You are analyzing a video transcript for translation preparation.

Source language: $sourceLanguage
Target language: $targetLanguage

Here is a sample of the transcript:
${sample.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

Please provide:
1. A brief summary of the content topic
2. Key terms and proper nouns that should be translated consistently
3. The overall tone (formal/informal/technical)

Keep your response concise (under 200 words).
''';

    final response = await _createChatCompletion(
      apiKey: _apiKey!,
      baseUrl: _baseUrl,
      model: model ?? _defaultModel,
      prompt: prompt,
      abortTrigger: abortTrigger,
    );
    return response.text ?? '';
  }

  @override
  Future<bool> validateApiKey(
    String apiKey, {
    String? model,
    String? baseUrl,
  }) async {
    try {
      final response = await _createChatCompletion(
        apiKey: apiKey,
        baseUrl: baseUrl,
        model: model ?? _defaultModel,
        prompt: 'Reply with a single word: OK',
      );
      final text = response.text ?? '';
      return text.toLowerCase().contains('ok');
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<String>> listModels(String apiKey, {String? baseUrl}) async {
    try {
      final response = await _sendJson(
        apiKey: apiKey,
        baseUrl: baseUrl,
        method: 'GET',
        path: '/models',
      );

      final data = response['data'];
      final models = <String>[];
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final id = item['id'];
            if (id is String && id.isNotEmpty) {
              models.add(id);
            }
          }
        }
      }

      models.sort((a, b) {
        if (a.contains('flash') && !b.contains('flash')) return -1;
        if (!a.contains('flash') && b.contains('flash')) return 1;
        return a.compareTo(b);
      });

      return models;
    } catch (e) {
      return ['Get models failed. Please check your API key and baseURL.'];
    }
  }

  @override
  void dispose() {
    _httpClient?.close();
    _httpClient = null;
    _apiKey = null;
    _baseUrl = null;
  }

  Future<_ChatCompletionResult> _createChatCompletion({
    required String apiKey,
    required String? baseUrl,
    required String model,
    required String prompt,
    Future<void>? abortTrigger,
  }) async {
    final response = await _sendJson(
      apiKey: apiKey,
      baseUrl: baseUrl,
      method: 'POST',
      path: '/chat/completions',
      abortTrigger: abortTrigger,
      body: {
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
    );

    return _ChatCompletionResult.fromJson(response);
  }

  Future<Map<String, dynamic>> _sendJson({
    required String apiKey,
    required String? baseUrl,
    required String method,
    required String path,
    Future<void>? abortTrigger,
    Map<String, dynamic>? body,
  }) async {
    _ensureClient(apiKey, baseUrl);

    final request = http.AbortableRequest(
      method,
      _buildUri(baseUrl, path),
      abortTrigger: abortTrigger,
    );
    request.headers.addAll({
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    });
    if (body != null) {
      request.body = jsonEncode(body);
    }

    try {
      final streamedResponse = await _httpClient!.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      return _decodeJsonResponse(response);
    } on http.RequestAbortedException {
      throw const TranslationAbortedException();
    }
  }

  Uri _buildUri(String? baseUrl, String path) {
    final rawBaseUrl = (baseUrl != null && baseUrl.trim().isNotEmpty)
        ? baseUrl.trim()
        : _defaultBaseUrl;
    final baseUri = Uri.parse(rawBaseUrl);

    if (!baseUri.hasScheme || baseUri.host.isEmpty) {
      throw FormatException('Invalid base URL: $rawBaseUrl');
    }

    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return baseUri.replace(path: '$basePath$normalizedPath');
  }

  Map<String, dynamic> _decodeJsonResponse(http.Response response) {
    final responseBody = utf8.decode(response.bodyBytes);
    Object? decoded;
    if (responseBody.isNotEmpty) {
      try {
        decoded = jsonDecode(responseBody);
      } on FormatException {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final errorMessage = responseBody.trim().isEmpty
              ? 'Unknown error'
              : responseBody.trim();
          throw Exception(
            'OpenAI API request failed (${response.statusCode}): $errorMessage',
          );
        }
        throw const FormatException('Expected a JSON object response.');
      }
    }
    final json = decoded is Map<String, dynamic> ? decoded : null;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMessage = _extractErrorMessage(json, responseBody);
      throw Exception(
        'OpenAI API request failed (${response.statusCode}): $errorMessage',
      );
    }

    if (json == null) {
      throw const FormatException('Expected a JSON object response.');
    }

    return json;
  }

  String _extractErrorMessage(Map<String, dynamic>? json, String responseBody) {
    if (json case {'error': final error}) {
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    }

    final trimmedBody = responseBody.trim();
    if (trimmedBody.isNotEmpty) {
      return trimmedBody;
    }

    return 'Unknown error';
  }

  String _buildTranslationPrompt({
    required List<String> texts,
    required String sourceLanguage,
    required String targetLanguage,
    List<String> contextBefore = const [],
    List<String> contextAfter = const [],
    Map<String, String> glossary = const {},
  }) {
    final buffer = StringBuffer();
    buffer.writeln('You are a professional subtitle translator.');
    buffer.writeln(
      'Translate the following subtitle lines from $sourceLanguage to $targetLanguage.',
    );
    buffer.writeln();
    buffer.writeln('RULES:');
    buffer.writeln('1. Keep translations natural and conversational');
    buffer.writeln('2. Maintain consistent terminology throughout');
    buffer.writeln('3. Return EXACTLY ${texts.length} translated lines');
    buffer.writeln(
      '4. Each translated line should correspond to the same numbered input line',
    );
    buffer.writeln(
      '5. Output ONLY the translations, one per line, numbered like: 1. translated text',
    );
    buffer.writeln(
      '6. Do NOT translate proper nouns unless there is a widely used translation',
    );
    buffer.writeln();

    if (glossary.isNotEmpty) {
      buffer.writeln('GLOSSARY (use these translations consistently):');
      glossary.forEach((source, target) {
        buffer.writeln('  "$source" -> "$target"');
      });
      buffer.writeln();
    }

    if (contextBefore.isNotEmpty) {
      buffer.writeln(
        'PRECEDING CONTEXT (already translated, for reference only):',
      );
      for (final line in contextBefore) {
        buffer.writeln('  - $line');
      }
      buffer.writeln();
    }

    buffer.writeln('LINES TO TRANSLATE:');
    for (var i = 0; i < texts.length; i++) {
      buffer.writeln('${i + 1}. ${texts[i]}');
    }

    if (contextAfter.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
        'FOLLOWING CONTEXT (for reference only, do NOT translate):',
      );
      for (final line in contextAfter) {
        buffer.writeln('  - $line');
      }
    }

    return buffer.toString();
  }

  List<String> _parseTranslationResponse(
    String response,
    int expectedCount,
    String? finishReason,
  ) {
    if (response.isEmpty) {
      if (finishReason != null && finishReason.isNotEmpty) {
        return List.filled(
          expectedCount,
          '[Translation stopped: $finishReason]',
        );
      }
      return List.filled(
        expectedCount,
        '[Translation error: The output may contain sensitive terms. Please try switching to a different model. 翻译错误，可能包含敏感词，请尝试更换模型]',
      );
    }

    final lines = response
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final results = <String>[];
    for (final line in lines) {
      final match = RegExp(r'^\d+[.:]\s*(.+)$').firstMatch(line);
      if (match != null) {
        results.add(match.group(1)!.trim());
      }
    }

    if (results.length != expectedCount && lines.length == expectedCount) {
      return lines;
    }

    while (results.length < expectedCount) {
      results.add('[Translation Error]');
    }

    return results.length > expectedCount
        ? results.sublist(0, expectedCount)
        : results;
  }
}

class _ChatCompletionResult {
  final String? text;
  final String? finishReason;

  const _ChatCompletionResult({this.text, this.finishReason});

  factory _ChatCompletionResult.fromJson(Map<String, dynamic> json) {
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) {
      return const _ChatCompletionResult();
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map<String, dynamic>) {
      return const _ChatCompletionResult();
    }

    final message = firstChoice['message'];
    final content = message is Map<String, dynamic> ? message['content'] : null;

    return _ChatCompletionResult(
      text: _extractTextContent(content),
      finishReason: firstChoice['finish_reason'] as String?,
    );
  }

  static String? _extractTextContent(Object? content) {
    if (content is String) {
      return content;
    }
    if (content is! List) {
      return null;
    }

    final parts = <String>[];
    for (final item in content) {
      if (item is Map<String, dynamic> && item['type'] == 'text') {
        final text = item['text'];
        if (text is String && text.isNotEmpty) {
          parts.add(text);
        }
      }
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join('\n');
  }
}
