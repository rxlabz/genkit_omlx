import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_omlx/genkit_omlx.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('RerankerAction integration (/v1/rerank)', () {
    test('reranks documents via ai.rerank and enriches document metadata', () async {
      late Map<String, dynamic> capturedBody;

      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, equals('/v1/rerank'));
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'model': 'BAAI/bge-reranker-v2-m3',
            'results': [
              {
                'index': 1,
                'relevance_score': 0.94,
                'document': {
                  'text': 'Apple Silicon shares LPDDR5X unified memory across CPU, GPU, and NPU.',
                },
              },
              {
                'index': 0,
                'relevance_score': 0.12,
                'document': {
                  'text': 'Sourdough fermentation takes several hours.',
                },
              },
            ],
            'usage': {'prompt_tokens': 32, 'total_tokens': 32},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final plugin = omlx(
        httpClient: mockClient,
        rerankers: const [
          OmlxRerankerDefinition(
            name: 'bge-reranker',
            model: 'BAAI/bge-reranker-v2-m3',
          ),
        ],
      );

      final ai = Genkit(plugins: [plugin]);
      final ranked = await ai.rerank(
        reranker: omlx.reranker('bge-reranker'),
        query: 'How does unified memory work on Apple Silicon?',
        documents: [
          DocumentData(
            content: [
              TextPart(text: 'Sourdough fermentation takes several hours.'),
            ],
            metadata: {'id': 'doc-a'},
          ),
          DocumentData(
            content: [
              TextPart(
                text:
                    'Apple Silicon shares LPDDR5X unified memory across CPU, GPU, and NPU.',
              ),
            ],
            metadata: {'id': 'doc-b'},
          ),
        ],
        options: OmlxRerankConfig(topN: 2),
      );

      expect(capturedBody['model'], equals('BAAI/bge-reranker-v2-m3'));
      expect(
        capturedBody['query'],
        equals('How does unified memory work on Apple Silicon?'),
      );
      expect(capturedBody['top_n'], equals(2));
      expect(capturedBody['return_documents'], isTrue);
      expect((capturedBody['documents'] as List).length, equals(2));

      expect(ranked.length, equals(2));
      expect(ranked.first.index, equals(1));
      expect(ranked.first.score, closeTo(0.94, 1e-6));
      expect(ranked.first.document.metadata?['id'], equals('doc-b'));
      expect(ranked.first.document.metadata?['score'], closeTo(0.94, 1e-6));
      expect(ranked.first.document.metadata?['index'], equals(1));

      expect(ranked[1].index, equals(0));
      expect(ranked[1].document.metadata?['id'], equals('doc-a'));
    });

    test('supports plugin.rerank convenience helper with plain texts', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'model': 'BAAI/bge-reranker-v2-m3',
            'results': [
              {'index': 0, 'relevance_score': 0.88},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final plugin = omlx(httpClient: mockClient);
      final ranked = await plugin.rerank(
        reranker: 'BAAI/bge-reranker-v2-m3',
        query: 'MLX continuous batching',
        texts: ['oMLX supports continuous batching on Apple Silicon.'],
        options: OmlxRerankConfig(topN: 1),
      );

      expect(ranked.length, equals(1));
      expect(ranked.first.index, equals(0));
      expect(ranked.first.score, closeTo(0.88, 1e-6));
    });

    test('short-circuits on empty documents list without calling server', () async {
      var calledServer = false;
      final mockClient = MockClient((request) async {
        calledServer = true;
        return http.Response('unexpected', 500);
      });

      final plugin = omlx(httpClient: mockClient);
      final ranked = await plugin.rerank(
        reranker: omlx.reranker('BAAI/bge-reranker-v2-m3'),
        query: 'test query',
        texts: const [],
      );

      expect(ranked, isEmpty);
      expect(calledServer, isFalse);
    });

    test('validates empty query, empty document text, and invalid topN', () async {
      final mockClient = MockClient(
        (request) async => http.Response('{"model":"m","results":[]}', 200),
      );
      final plugin = omlx(httpClient: mockClient);

      // Empty query
      expect(
        () => plugin.rerank(
          reranker: 'BAAI/bge-reranker-v2-m3',
          query: '   ',
          texts: ['valid doc'],
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCode.invalidArgument,
          ),
        ),
      );

      // Empty document text
      expect(
        () => plugin.rerank(
          reranker: 'BAAI/bge-reranker-v2-m3',
          query: 'valid query',
          texts: ['valid doc', '   '],
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCode.invalidArgument,
          ),
        ),
      );

      // Invalid topN < 1
      expect(
        () => plugin.rerank(
          reranker: 'BAAI/bge-reranker-v2-m3',
          query: 'valid query',
          texts: ['valid doc'],
          options: OmlxRerankConfig(topN: 0),
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCode.invalidArgument,
          ),
        ),
      );
    });
  });
}
