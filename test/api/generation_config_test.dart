import 'package:genkit_omlx/genkit_omlx.dart';
import 'package:test/test.dart';

void main() {
  group('OmlxGenerationConfig', () {
    test('parses from null map', () {
      final config = OmlxGenerationConfig.fromJson(null);
      expect(config.temperature, isNull);
      expect(config.topP, isNull);
      expect(config.topK, isNull);
      expect(config.maxTokens, isNull);
      expect(config.stop, isNull);
    });

    test('parses camelCase and snake_case fields correctly', () {
      final config = OmlxGenerationConfig.fromJson({
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
      final config = OmlxGenerationConfig.fromJson({
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
  });

  group('OmlxEmbedConfig', () {
    test('parses fields and serializes to json', () {
      final config = OmlxEmbedConfig.fromJson({
        'dimensions': 768,
        'encoding_format': 'float',
        'user': 'test_user',
      });

      expect(config.dimensions, equals(768));
      expect(config.encodingFormat, equals('float'));
      expect(config.user, equals('test_user'));

      final json = config.toJson();
      expect(json['dimensions'], equals(768));
      expect(json['encoding_format'], equals('float'));
      expect(json['user'], equals('test_user'));
    });
  });
}
