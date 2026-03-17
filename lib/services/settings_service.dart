import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ProviderCredential {
  final String baseUrl;
  final String apiKey;

  const ProviderCredential({required this.baseUrl, required this.apiKey});

  Map<String, String> toJson() => {'baseUrl': baseUrl, 'apiKey': apiKey};

  factory ProviderCredential.fromJson(Map<String, dynamic> json) {
    return ProviderCredential(
      baseUrl: json['baseUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
    );
  }
}

/// Service for persisting user settings like API keys and model preferences.
class SettingsService {
  static const String _keyGeminiApiKey = 'gemini_api_key';
  static const String _keyGeminiModel = 'gemini_model';
  static const String _keyLlmProvider = 'llm_provider';
  static const String _keyLlmBaseUrl = 'llm_base_url';
  static const String _keyLlmProviderCredentials = 'llm_provider_credentials';
  static const String _keyTargetLanguage = 'target_language';
  static const String _keyBilingual = 'bilingual';
  static const String _keyBatchSize = 'batch_size';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  static Future<SettingsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }

  String get geminiApiKey => _prefs.getString(_keyGeminiApiKey) ?? '';
  Future<void> setGeminiApiKey(String value) =>
      _prefs.setString(_keyGeminiApiKey, value);

  String get geminiModel =>
      _prefs.getString(_keyGeminiModel) ?? 'gemini-2.0-flash';
  Future<void> setGeminiModel(String value) =>
      _prefs.setString(_keyGeminiModel, value);

  String get llmProvider {
    final provider = _prefs.getString(_keyLlmProvider);
    if (provider == null || provider.isEmpty || provider == 'google') {
      return 'Gemini (Google)';
    }
    return provider;
  }

  Future<void> setLlmProvider(String value) =>
      _prefs.setString(_keyLlmProvider, value);

  String get llmBaseUrl =>
      _prefs.getString(_keyLlmBaseUrl) ??
      'https://generativelanguage.googleapis.com/v1beta/openai';
  Future<void> setLlmBaseUrl(String value) =>
      _prefs.setString(_keyLlmBaseUrl, value);

  String get targetLanguage => _prefs.getString(_keyTargetLanguage) ?? 'zh';
  Future<void> setTargetLanguage(String value) =>
      _prefs.setString(_keyTargetLanguage, value);

  bool get bilingual => _prefs.getBool(_keyBilingual) ?? true;
  Future<void> setBilingual(bool value) => _prefs.setBool(_keyBilingual, value);

  int get batchSize => _prefs.getInt(_keyBatchSize) ?? 25;
  Future<void> setBatchSize(int value) => _prefs.setInt(_keyBatchSize, value);

  Map<String, ProviderCredential> get llmProviderCredentials {
    final raw = _prefs.getString(_keyLlmProviderCredentials);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return decoded.map((provider, value) {
        if (value is! Map<String, dynamic>) {
          return MapEntry(
            provider,
            const ProviderCredential(baseUrl: '', apiKey: ''),
          );
        }
        return MapEntry(provider, ProviderCredential.fromJson(value));
      });
    } catch (_) {
      return {};
    }
  }

  Future<void> saveLlmProviderCredential(
    String provider,
    ProviderCredential credential,
  ) async {
    final credentials = Map<String, ProviderCredential>.from(
      llmProviderCredentials,
    );
    credentials[provider] = credential;
    await _prefs.setString(
      _keyLlmProviderCredentials,
      jsonEncode(
        credentials.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
  }

  Future<void> deleteLlmProviderCredential(String provider) async {
    final credentials = Map<String, ProviderCredential>.from(
      llmProviderCredentials,
    );
    credentials.remove(provider);
    await _prefs.setString(
      _keyLlmProviderCredentials,
      jsonEncode(
        credentials.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
  }
}
