import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_omlx/genkit_omlx.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('EmbedderAction integration', () {
    test('generates batch embeddings via oMLX', () async {
      late String capturedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/embeddings') {
          capturedBody = request.body;
          final responsePayload = {
            'object': 'list',
            'model': 'bge-micro',
            'data': [
              {
                'object': 'embedding',
                'index': 0,
                'embedding': [0.1, 0.2, 0.3],
              },
              {
                'object': 'embedding',
                'index': 1,
                'embedding': [0.4, 0.5, 0.6],
              },
            ],
            'usage': {'prompt_tokens': 8, 'total_tokens': 8},
          };
          return http.Response(
            jsonEncode(responsePayload),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final plugin = omlx(
        httpClient: mockClient,
        embedders: const [
          OmlxEmbedderDefinition(name: 'bge-micro', dimensions: 3),
        ],
      );

      final ai = Genkit(plugins: [plugin]);
      final response = await ai.embed(
        embedder: omlx.embedder('bge-micro'),
        documents: [
          DocumentData(content: [TextPart(text: 'first text')]),
          DocumentData(content: [TextPart(text: 'second text')]),
        ],
        options: OmlxEmbedConfig(dimensions: 3),
      );

      expect(response.length, equals(2));
      expect(response[0].embedding, equals([0.1, 0.2, 0.3]));
      expect(response[1].embedding, equals([0.4, 0.5, 0.6]));

      final decoded = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(decoded['model'], equals('bge-micro'));
      expect(decoded['input'], equals(['first text', 'second text']));
      expect(decoded['dimensions'], equals(3));
    });
  });
}
