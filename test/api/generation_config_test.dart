import 'package:genkit_omlx/genkit_omlx.dart';
import 'package:test/test.dart';

void main() {
  group('OmlxGenerationConfig', () {
    test('parses from null map', () {
      final config = parseOmlxGenerationConfig(null);
      expect(config.temperature, isNull);
      expect(config.topP, isNull);
      expect(config.topK, isNull);
      expect(config.maxTokens, isNull);
      expect(config.stop, isNull);
    });

    test('parses camelCase and snake_case fields correctly', () {
      final config = parseOmlxGenerationConfig({
        'temperature': 0.7,
        'top_p': 0.85,
        'top_k': 50,
        'repetition_penalty': 1.15,
        'max_tokens': 1024,
        'stop': ['<|endoftext|>'],
        'user': 'user_123',
      });

      expect(config.temperature, equals(0.7));
      expect(config.topP, equals(0.85));
      expect(config.topK, equals(50));
      expect(config.repetitionPenalty, equals(1.15));
      expect(config.maxTokens, equals(1024));
      expect(config.stop, equals(['<|endoftext|>']));
      expect(config.user, equals('user_123'));
    });

    test('preserves extra custom vendor options', () {
      final config = parseOmlxGenerationConfig({
        'temperature': 0.2,
        'custom_engine_param': true,
        'draft_model': 'qwen-0.5b',
      });

      expect(config.temperature, equals(0.2));
      expect(config.extra?['custom_engine_param'], isTrue);
      expect(config.extra?['draft_model'], equals('qwen-0.5b'));

      final json = config.toJson();
      expect(json['temperature'], equals(0.2));
      expect(json['custom_engine_param'], isTrue);
      expect(json['draft_model'], equals('qwen-0.5b'));
    });

    test('provides Dev UI JSON schema with bounds', () {
      final schema = omlxGenerationConfigSchema().jsonSchema();
      expect(schema['type'], equals('object'));
      final properties = schema['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('temperature'), isTrue);
      expect(properties['temperature']['minimum'], equals(0.0));
      expect(properties['temperature']['maximum'], equals(2.0));
      expect(properties.containsKey('topP'), isTrue);
      expect(properties['topP']['minimum'], equals(0.0));
      expect(properties['topP']['maximum'], equals(1.0));
      expect(properties['topK']['minimum'], equals(1));
      expect(properties['maxTokens']['minimum'], equals(1));
    });
  });

  group('OmlxEmbedConfig', () {
    test('parses from null map', () {
      final config = parseOmlxEmbedConfig(null);
      expect(config.dimensions, isNull);
      expect(config.user, isNull);
    });

    test('parses fields and serializes to json', () {
      final config = parseOmlxEmbedConfig({
        'dimensions': 768,
        'user': 'test_user',
      });

      expect(config.dimensions, equals(768));
      expect(config.user, equals('test_user'));

      final json = config.toJson();
      expect(json['dimensions'], equals(768));
      expect(json['user'], equals('test_user'));
    });

    test('provides Dev UI JSON schema with bounds', () {
      final schema = omlxEmbedConfigSchema().jsonSchema();
      expect(schema['type'], equals('object'));
      final properties = schema['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('dimensions'), isTrue);
      expect(properties['dimensions']['minimum'], equals(1));
      expect(properties.containsKey('user'), isTrue);
    });
  });

  group('OmlxSpeechConfig', () {
    test('parses camelCase and snake_case fields correctly', () {
      final config = parseOmlxSpeechConfig({
        'version': 'mlx-community/Kokoro-82M-bf16',
        'voice': 'af_heart',
        'response_format': 'wav',
        'speed': 1.25,
      });

      expect(config.version, equals('mlx-community/Kokoro-82M-bf16'));
      expect(config.voice, equals('af_heart'));
      expect(config.responseFormat, equals('wav'));
      expect(config.speed, equals(1.25));
    });

    test('provides Dev UI JSON schema with speed bounds', () {
      final schema = omlxSpeechConfigSchema().jsonSchema();
      expect(schema['type'], equals('object'));
      final properties = schema['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('voice'), isTrue);
      expect(properties.containsKey('response_format'), isTrue);
      expect(properties['speed']['minimum'], equals(0.25));
      expect(properties['speed']['maximum'], equals(4.0));
    });
  });

  group('OmlxTranscriptionConfig', () {
    test('parses camelCase and snake_case fields correctly', () {
      final config = parseOmlxTranscriptionConfig({
        'version': 'mlx-community/whisper-large-v3-turbo',
        'language': 'fr',
        'prompt': 'Technical glossary',
        'response_format': 'verbose_json',
        'temperature': 0.1,
      });

      expect(config.version, equals('mlx-community/whisper-large-v3-turbo'));
      expect(config.language, equals('fr'));
      expect(config.prompt, equals('Technical glossary'));
      expect(config.responseFormat, equals('verbose_json'));
      expect(config.temperature, equals(0.1));
    });

    test('provides Dev UI JSON schema with temperature bounds', () {
      final schema = omlxTranscriptionConfigSchema().jsonSchema();
      expect(schema['type'], equals('object'));
      final properties = schema['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('language'), isTrue);
      expect(properties.containsKey('prompt'), isTrue);
      expect(properties.containsKey('response_format'), isTrue);
      expect(properties['temperature']['minimum'], equals(0.0));
      expect(properties['temperature']['maximum'], equals(1.0));
    });
  });

  group('OmlxRerankConfig', () {
    test('parses camelCase and snake_case fields correctly', () {
      final config = parseOmlxRerankConfig({
        'version': 'BAAI/bge-reranker-v2-m3',
        'topN': 5,
        'returnDocuments': false,
      });

      expect(config.version, equals('BAAI/bge-reranker-v2-m3'));
      expect(config.topN, equals(5));
      expect(config.returnDocuments, isFalse);
    });

    test('provides Dev UI JSON schema with top_n bounds', () {
      final schema = omlxRerankConfigSchema().jsonSchema();
      expect(schema['type'], equals('object'));
      final properties = schema['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('top_n'), isTrue);
      expect(properties['top_n']['minimum'], equals(1));
      expect(properties.containsKey('return_documents'), isTrue);
    });
  });
}
