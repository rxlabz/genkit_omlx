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

    test('short-circuits when input documents list is empty', () async {
      var clientCalled = false;
      final mockClient = MockClient((request) async {
        clientCalled = true;
        return http.Response('Should not be called', 500);
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
        documents: [],
      );

      expect(response, isEmpty);
      expect(clientCalled, isFalse);
    });

    test('sorts embeddings response by item index', () async {
      final mockClient = MockClient((request) async {
        final responsePayload = {
          'object': 'list',
          'model': 'bge-micro',
          'data': [
            // Out of order: index 1 first, index 0 second
            {
              'object': 'embedding',
              'index': 1,
              'embedding': [0.4, 0.5, 0.6],
            },
            {
              'object': 'embedding',
              'index': 0,
              'embedding': [0.1, 0.2, 0.3],
            },
          ],
          'usage': {'prompt_tokens': 4, 'total_tokens': 4},
        };
        return http.Response(
          jsonEncode(responsePayload),
          200,
          headers: {'content-type': 'application/json'},
        );
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
          DocumentData(content: [TextPart(text: 'doc 0')]),
          DocumentData(content: [TextPart(text: 'doc 1')]),
        ],
      );

      expect(response.length, equals(2));
      expect(response[0].embedding, equals([0.1, 0.2, 0.3]));
      expect(response[1].embedding, equals([0.4, 0.5, 0.6]));
    });

    test('maps OmlxApiException 507 to GenkitException resourceExhausted', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'message': 'Unified memory limit reached while allocating embedding tensor',
              'type': 'out_of_memory_error',
              'code': 507,
            },
          }),
          507,
          headers: {'content-type': 'application/json'},
        );
      });

      final plugin = omlx(
        httpClient: mockClient,
        embedders: const [
          OmlxEmbedderDefinition(name: 'bge-micro', dimensions: 3),
        ],
      );

      final ai = Genkit(plugins: [plugin]);
      expect(
        () => ai.embed(
          embedder: omlx.embedder('bge-micro'),
          documents: [
            DocumentData(content: [TextPart(text: 'test text')]),
          ],
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            equals(StatusCode.resourceExhausted),
          ),
        ),
      );
    });

    test('batches large document inputs into maxEmbeddingBatchSize chunks', () async {
      final capturedBatches = <List<String>>[];

      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/embeddings') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final inputs = (body['input'] as List).cast<String>();
          capturedBatches.add(inputs);

          final responsePayload = {
            'object': 'list',
            'model': 'bge-micro',
            'data': [
              for (var i = 0; i < inputs.length; i++)
                {
                  'object': 'embedding',
                  'index': i,
                  'embedding': [i.toDouble()],
                },
            ],
            'usage': {'prompt_tokens': inputs.length, 'total_tokens': inputs.length},
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
        embedders: const [OmlxEmbedderDefinition(name: 'bge-micro')],
      );

      final totalDocs = 520;
      final docs = List.generate(
        totalDocs,
        (i) => DocumentData(content: [TextPart(text: 'text item $i')]),
      );

      final ai = Genkit(plugins: [plugin]);
      final response = await ai.embed(
        embedder: omlx.embedder('bge-micro'),
        documents: docs,
      );

      expect(response.length, equals(520));
      expect(capturedBatches.length, equals(2));
      expect(capturedBatches[0].length, equals(512));
      expect(capturedBatches[1].length, equals(8));
    });

    test('rejects document with empty text content', () async {
      final mockClient = MockClient((request) async => http.Response('ok', 200));
      final plugin = omlx(
        httpClient: mockClient,
        embedders: const [OmlxEmbedderDefinition(name: 'bge-micro')],
      );

      final ai = Genkit(plugins: [plugin]);
      expect(
        () => ai.embed(
          embedder: omlx.embedder('bge-micro'),
          documents: [
            DocumentData(content: [TextPart(text: '   ')]),
          ],
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            equals(StatusCode.invalidArgument),
          ),
        ),
      );
    });

    test('validates server returns expected embedding count', () async {
      final mockClient = MockClient((request) async {
        final responsePayload = {
          'object': 'list',
          'model': 'bge-micro',
          'data': [
            // Returns only 1 item when 2 were sent
            {
              'object': 'embedding',
              'index': 0,
              'embedding': [0.1],
            },
          ],
        };
        return http.Response(
          jsonEncode(responsePayload),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final plugin = omlx(
        httpClient: mockClient,
        embedders: const [OmlxEmbedderDefinition(name: 'bge-micro')],
      );

      final ai = Genkit(plugins: [plugin]);
      expect(
        () => ai.embed(
          embedder: omlx.embedder('bge-micro'),
          documents: [
            DocumentData(content: [TextPart(text: 'doc 0')]),
            DocumentData(content: [TextPart(text: 'doc 1')]),
          ],
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            equals(StatusCode.internal),
          ),
        ),
      );
    });
  });
}
