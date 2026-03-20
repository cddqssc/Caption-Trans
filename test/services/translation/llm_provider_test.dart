import 'dart:async';
import 'dart:convert';

import 'package:caption_trans/services/translation/llm_provider.dart';
import 'package:caption_trans/services/translation/translation_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('LlmProvider', () {
    test('translateBatch parses numbered chat completions response', () async {
      var requestCount = 0;
      final provider = LlmProvider(
        providerId: 'OpenAI',
        clientFactory: () => MockClient((request) async {
          requestCount++;
          expect(
            request.url.toString(),
            'https://api.openai.com/v1/chat/completions',
          );
          expect(request.headers['authorization'], 'Bearer test-key');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['model'], 'gpt-4o');
          expect(body['messages'], hasLength(1));

          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': requestCount == 1
                        ? 'OK'
                        : '1. first line\n2. second line',
                  },
                  'finish_reason': 'stop',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final isValid = await provider.validateApiKey('test-key');
      expect(isValid, isTrue);

      final result = await provider.translateBatch(
        texts: const ['hello', 'world'],
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );

      expect(result, ['first line', 'second line']);
    });

    test('listModels returns sorted ids from models endpoint', () async {
      final provider = LlmProvider(
        providerId: 'OpenAI',
        clientFactory: () => MockClient((request) async {
          expect(request.url.toString(), 'https://example.com/v1/models');
          expect(request.method, 'GET');

          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'gpt-4o'},
                {'id': 'gemini-2.5-flash'},
                {'id': 'gpt-4.1-mini'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final models = await provider.listModels(
        'test-key',
        baseUrl: 'https://example.com/v1',
      );

      expect(models, ['gemini-2.5-flash', 'gpt-4.1-mini', 'gpt-4o']);
    });

    test(
      'translateBatch throws TranslationAbortedException when aborted',
      () async {
        final abortCompleter = Completer<void>()..complete();
        final provider = LlmProvider(
          providerId: 'OpenAI',
          clientFactory: () => MockClient.streaming((
            request,
            bodyStream,
          ) async {
            if (request case http.Abortable(:final abortTrigger?)) {
              await abortTrigger;
              throw http.RequestAbortedException(request.url);
            }

            return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
          }),
        );

        final isValid = await provider.validateApiKey('test-key');
        expect(isValid, isFalse);

        await expectLater(
          provider.translateBatch(
            texts: const ['hello'],
            sourceLanguage: 'en',
            targetLanguage: 'zh',
            abortTrigger: abortCompleter.future,
          ),
          throwsA(isA<TranslationAbortedException>()),
        );
      },
    );
  });
}
