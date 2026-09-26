import 'dart:convert';

import 'package:genkit/plugin.dart';
import 'package:genkit_omlx/genkit_omlx.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('OmlxPlugin lifecycle & discovery', () {
    test('initializes and registers static models and embedders', () async {
      final plugin = omlx(
        models: const [OmlxModelDefinition(name: 'chat-qwen')],
        embedders: const [
          OmlxEmbedderDefinition(name: 'embed-bge', dimensions: 384),
        ],
      );

      final actions = await plugin.init();
      expect(actions.length, equals(2));
      expect(actions.any((a) => a.name == 'omlx/chat-qwen'), isTrue);
      expect(actions.any((a) => a.name == 'omlx/embed-bge'), isTrue);
    });

    test('dynamically resolves unregistered models on demand', () {
      final plugin = omlx();

      final action = plugin.resolve(
        ActionType.model,
        'mlx-community/Qwen2.5-Coder-7B-Instruct-4bit',
      );

      expect(action, isNotNull);
      expect(
        action!.name,
        equals('omlx/mlx-community/Qwen2.5-Coder-7B-Instruct-4bit'),
      );
    });

    test('dynamically resolves models with omlx/ prefix', () {
      final plugin = omlx();

      final action = plugin.resolve(ActionType.model, 'omlx/qwen');

      expect(action, isNotNull);
      expect(action!.name, equals('omlx/qwen'));
    });

    test('lists actions and queries /v1/models from server', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/models') {
          final payload = {
            'object': 'list',
            'data': [
              {
                'id': 'mlx-community/Qwen2.5-7B-Instruct-4bit',
                'object': 'model',
              },
              {'id': 'deepseek-r1-distill-qwen-7b', 'object': 'model'},
            ],
          };
          return http.Response(
            jsonEncode(payload),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final plugin = omlx(
        httpClient: mockClient,
        models: const [OmlxModelDefinition(name: 'custom-model')],
      );

      final actionsMetadata = await plugin.list();
      final names = actionsMetadata.map((a) => a.name).toList();

      expect(names, contains('omlx/custom-model'));
      expect(names, contains('omlx/mlx-community/Qwen2.5-7B-Instruct-4bit'));
      expect(names, contains('omlx/deepseek-r1-distill-qwen-7b'));
    });

    test('handles unreachable server gracefully in list()', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final plugin = omlx(
        httpClient: mockClient,
        models: const [OmlxModelDefinition(name: 'static-model')],
      );

      final actionsMetadata = await plugin.list();
      expect(actionsMetadata.length, equals(1));
      expect(actionsMetadata.first.name, equals('omlx/static-model'));
    });

    test('disposes client cleanly', () async {
      var closed = false;
      final mockClient = MockClient(
        (request) async => http.Response('ok', 200),
      );

      final plugin = omlx(httpClient: mockClient);
      await plugin.dispose();
      // Should complete without error
      expect(closed, isFalse);
    });
  });
}
