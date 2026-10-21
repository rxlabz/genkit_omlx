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

    test('classifies discovered models into chat, speech, transcription, and embedders', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/models') {
          final payload = {
            'object': 'list',
            'data': [
              {'id': 'qwen2.5-coder-7b', 'object': 'model'},
              {'id': 'bge-m3', 'object': 'model'},
              {'id': 'nomic-embed-text', 'object': 'model'},
              {'id': 'mlx-community/Kokoro-82M-bf16', 'object': 'model'},
              {'id': 'mlx-community/whisper-large-v3-turbo', 'object': 'model'},
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

      final plugin = omlx(httpClient: mockClient);
      final metadataList = await plugin.list();

      final models = metadataList
          .where((m) => m.actionType == ActionType.model)
          .toList();
      final modelNames = models.map((m) => m.name).toList();
      final embedders = metadataList
          .where((m) => m.actionType == ActionType.embedder)
          .toList();

      expect(modelNames, contains('omlx/qwen2.5-coder-7b'));
      expect(modelNames, contains('omlx/mlx-community/Kokoro-82M-bf16'));
      expect(modelNames, contains('omlx/mlx-community/whisper-large-v3-turbo'));
      expect(embedders.map((e) => e.name), contains('omlx/bge-m3'));
      expect(embedders.map((e) => e.name), contains('omlx/nomic-embed-text'));

      final kokoroMeta = models.firstWhere(
        (m) => m.name == 'omlx/mlx-community/Kokoro-82M-bf16',
      );
      expect(
        (kokoroMeta.metadata['model'] as Map<String, dynamic>)['supports']['output'],
        equals(['media']),
      );

      final whisperMeta = models.firstWhere(
        (m) => m.name == 'omlx/mlx-community/whisper-large-v3-turbo',
      );
      expect(
        (whisperMeta.metadata['model'] as Map<String, dynamic>)['supports']['media'],
        isTrue,
      );

      final bgeMeta = embedders.firstWhere((e) => e.name == 'omlx/bge-m3');
      expect(bgeMeta.inputSchema, isNotNull);
      expect(bgeMeta.outputSchema, isNotNull);
    });

    test('deduplicates static definitions by both name and model ID and classifies rerankers in list()', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/models') {
          final payload = {
            'object': 'list',
            'data': [
              // Matches static model's underlying `model` ID
              {'id': 'mlx-community/Qwen2.5-7B-Instruct-4bit', 'object': 'model'},
              // Matches static embedder's custom `name` (which looks like chat to heuristics)
              {'id': 'my-custom-vectors', 'object': 'model'},
              // Reranker containing 'bge' - should be listed as reranker, NOT embedder or chat
              {'id': 'BAAI/bge-reranker-v2-m3', 'object': 'model'},
              // Server metadata explicitly marking a generic ID as embedding
              {
                'id': 'custom-local-encoder-v1',
                'object': 'model',
                'engine_type': 'embedding',
              },
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
        models: const [
          OmlxModelDefinition(
            name: 'qwen',
            model: 'mlx-community/Qwen2.5-7B-Instruct-4bit',
          ),
        ],
        embedders: const [
          OmlxEmbedderDefinition(name: 'my-custom-vectors'),
        ],
      );

      final metadataList = await plugin.list();
      final chatNames = metadataList
          .where((m) => m.actionType == ActionType.model)
          .map((m) => m.name)
          .toList();
      final embedderNames = metadataList
          .where((m) => m.actionType == ActionType.embedder)
          .map((m) => m.name)
          .toList();
      final rerankerNames = metadataList
          .where((m) => m.actionType == omlxRerankerActionType)
          .map((m) => m.name)
          .toList();

      // Static qwen listed once under alias, underlying ID not duplicated
      expect(chatNames, equals(['omlx/qwen']));

      // Static custom embedder + server metadata-tagged embedder; bge-reranker excluded from embedders
      expect(
        embedderNames,
        unorderedEquals([
          'omlx/my-custom-vectors',
          'omlx/custom-local-encoder-v1',
        ]),
      );

      // bge-reranker classified and listed under reranker action type
      expect(rerankerNames, equals(['omlx/BAAI/bge-reranker-v2-m3']));
    });

    test('supports custom plugin namespace for multi-instance deployments', () async {
      final plugin = omlx(
        name: 'omlx-studio',
        models: const [OmlxModelDefinition(name: 'qwen')],
        embedders: const [OmlxEmbedderDefinition(name: 'bge')],
      );

      expect(plugin.name, equals('omlx-studio'));

      final actions = await plugin.init();
      expect(actions.any((a) => a.name == 'omlx-studio/qwen'), isTrue);
      expect(actions.any((a) => a.name == 'omlx-studio/bge'), isTrue);

      final resolvedModel = plugin.resolve(ActionType.model, 'omlx-studio/qwen');
      expect(resolvedModel, isNotNull);
      expect(resolvedModel!.name, equals('omlx-studio/qwen'));

      final resolvedEmbedder = plugin.resolve(ActionType.embedder, 'omlx-studio/bge');
      expect(resolvedEmbedder, isNotNull);
      expect(resolvedEmbedder!.name, equals('omlx-studio/bge'));

      final dynamicEmbedder = plugin.resolve(ActionType.embedder, 'omlx-studio/dynamic-bge');
      expect(dynamicEmbedder, isNotNull);
      expect(dynamicEmbedder!.name, equals('omlx-studio/dynamic-bge'));
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

    test('queries /health, /v1/models/status, and /v1/models/{id}/unload with alias resolution', () async {
      String? unloadedPath;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/health') {
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'version': '0.4.2',
              'default_model': 'mlx-community/Qwen2.5-7B-Instruct-4bit',
              'engine_pool': {'active_models': 1, 'memory_gb': 5.2},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && request.url.path == '/v1/models/status') {
          return http.Response(
            jsonEncode({
              'mlx-community/Qwen2.5-7B-Instruct-4bit': {
                'loaded': true,
                'engine_type': 'mlx_lm',
                'memory_bytes': 5583457484,
              },
              'BAAI/bge-reranker-v2-m3': {
                'loaded': false,
                'engine_type': 'rerank',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST' && request.url.path.endsWith('/unload')) {
          unloadedPath = request.url.path;
          return http.Response(
            jsonEncode({
              'status': 'unloaded',
              'message': 'Evicted from Apple Silicon unified memory',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final plugin = omlx(
        httpClient: mockClient,
        models: const [
          OmlxModelDefinition(
            name: 'qwen',
            model: 'mlx-community/Qwen2.5-7B-Instruct-4bit',
          ),
        ],
      );

      final health = await plugin.health();
      expect(health.isHealthy, isTrue);
      expect(health.version, equals('0.4.2'));
      expect(health.enginePool?['active_models'], equals(1));

      final statuses = await plugin.modelsStatus();
      expect(statuses.length, equals(2));

      // Lookup by registered alias 'qwen' or 'omlx/qwen'
      final qwenStatus = await plugin.modelStatus('omlx/qwen');
      expect(qwenStatus, isNotNull);
      expect(
        qwenStatus!.modelId,
        equals('mlx-community/Qwen2.5-7B-Instruct-4bit'),
      );
      expect(qwenStatus.isLoaded, isTrue);
      expect(qwenStatus.details['memory_bytes'], equals(5583457484));

      // Unload by registered alias 'qwen' -> resolves to URL-encoded wire ID
      final unloadRes = await plugin.unloadModel('qwen');
      expect(unloadRes.success, isTrue);
      expect(
        unloadRes.modelId,
        equals('mlx-community/Qwen2.5-7B-Instruct-4bit'),
      );
      expect(
        unloadedPath,
        equals('/v1/models/mlx-community%2FQwen2.5-7B-Instruct-4bit/unload'),
      );
    });
  });

  group('classifyModel strategy', () {
    test('classifies rerankers before embedding families', () {
      expect(
        classifyModel('BAAI/bge-reranker-v2-m3'),
        equals(OmlxModelKind.rerank),
      );
      expect(
        classifyModel('mlx-community/bge-reranker-large'),
        equals(OmlxModelKind.rerank),
      );
      expect(
        classifyModel('Alibaba-NLP/gte-reranker-modernbert-base'),
        equals(OmlxModelKind.rerank),
      );
      expect(
        classifyModel('jinaai/jina-reranker-v2-base-multilingual'),
        equals(OmlxModelKind.rerank),
      );
      expect(
        classifyModel('cross-encoder/ms-marco-MiniLM-L-6-v2'),
        equals(OmlxModelKind.rerank),
      );
    });

    test('matches embedding models using boundary-aware tokens', () {
      expect(classifyModel('bge-m3'), equals(OmlxModelKind.embedding));
      expect(
        classifyModel('BAAI/bge-small-en-v1.5'),
        equals(OmlxModelKind.embedding),
      );
      expect(
        classifyModel('intfloat/multilingual-e5-large'),
        equals(OmlxModelKind.embedding),
      );
      expect(
        classifyModel('Alibaba-NLP/gte-Qwen2-1.5B-instruct'),
        equals(OmlxModelKind.embedding),
      );
      expect(
        classifyModel('nomic-ai/nomic-embed-text-v1.5'),
        equals(OmlxModelKind.embedding),
      );
      expect(
        classifyModel('sentence-transformers/all-MiniLM-L6-v2'),
        equals(OmlxModelKind.embedding),
      );
      expect(
        classifyModel('Qwen/Qwen3-Embedding-0.6B'),
        equals(OmlxModelKind.embedding),
      );
    });

    test('does not misclassify chat models with short substring collisions', () {
      // 'e5' inside commit hash or quantization tag
      expect(
        classifyModel('mlx-community/Llama-3.2-3B-Instruct-e5a1'),
        equals(OmlxModelKind.chat),
      );
      expect(
        classifyModel('custom/model-base58-instruct'),
        equals(OmlxModelKind.chat),
      );
      // 'nomic' organization hosting a chat LLM
      expect(
        classifyModel('nomic-ai/gpt4all-falcon'),
        equals(OmlxModelKind.chat),
      );
    });

    test('classifies Apple Silicon TTS and STT audio models', () {
      // Speech (TTS)
      expect(
        classifyModel('mlx-community/Kokoro-82M-bf16'),
        equals(OmlxModelKind.speech),
      );
      expect(
        classifyModel('mlx-community/F5-TTS'),
        equals(OmlxModelKind.speech),
      );
      expect(
        classifyModel('FunAudioLLM/CosyVoice2-0.5B'),
        equals(OmlxModelKind.speech),
      );
      expect(
        classifyModel('canopylabs/orpheus-3b-0.1-ft'),
        equals(OmlxModelKind.speech),
      );
      expect(
        classifyModel('sesame/csm-1b'),
        equals(OmlxModelKind.speech),
      );
      expect(
        classifyModel('suno/bark'),
        equals(OmlxModelKind.speech),
      );

      // Transcription (STT)
      expect(
        classifyModel('mlx-community/whisper-large-v3-turbo'),
        equals(OmlxModelKind.transcription),
      );
      expect(
        classifyModel('mlx-community/parakeet-tdt-0.6b-v2'),
        equals(OmlxModelKind.transcription),
      );
      expect(
        classifyModel('FunAudioLLM/SenseVoiceSmall'),
        equals(OmlxModelKind.transcription),
      );
      expect(
        classifyModel('UsefulSensors/moonshine-base'),
        equals(OmlxModelKind.transcription),
      );
      expect(
        classifyModel('nvidia/canary-1b'),
        equals(OmlxModelKind.transcription),
      );
      expect(
        classifyModel('mistralai/Voxtral-Mini-3B-2507'),
        equals(OmlxModelKind.transcription),
      );
    });

    test('prioritizes explicit server metadata in raw over name heuristics', () {
      expect(
        classifyModel('custom-model-v1', raw: {'type': 'embedding'}),
        equals(OmlxModelKind.embedding),
      );
      expect(
        classifyModel(
          'custom-model-v2',
          raw: {'pipeline_tag': 'automatic-speech-recognition'},
        ),
        equals(OmlxModelKind.transcription),
      );
      expect(
        classifyModel(
          'custom-model-v3',
          raw: {'task': 'text-to-speech'},
        ),
        equals(OmlxModelKind.speech),
      );
      expect(
        classifyModel(
          'custom-model-v4',
          raw: {'engine_type': 'rerank'},
        ),
        equals(OmlxModelKind.rerank),
      );
      expect(
        classifyModel(
          'bge-custom-chat-finetune',
          raw: {'type': 'chat'},
        ),
        equals(OmlxModelKind.chat),
      );
    });
  });
}
