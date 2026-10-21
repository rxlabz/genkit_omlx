import 'package:genkit_omlx/genkit_omlx.dart';
import 'package:test/test.dart';

void main() {
  group('OmlxPluginHandle', () {
    test('creates plugin instance with default options', () {
      final plugin = omlx();
      expect(plugin.name, equals('omlx'));
      expect(plugin.clientManager.baseUrl, equals('http://localhost:8000'));
      expect(plugin.clientManager.apiKey, isNull);
    });

    test('creates plugin instance with custom baseUrl and apiKey', () {
      final plugin = omlx(
        baseUrl: 'http://192.168.1.50:8000',
        apiKey: 'secret-token',
      );
      expect(plugin.clientManager.baseUrl, equals('http://192.168.1.50:8000'));
      expect(plugin.clientManager.apiKey, equals('secret-token'));
    });

    test('creates plugin instance with custom namespace', () {
      final plugin = omlx(name: 'omlx-studio');
      expect(plugin.name, equals('omlx-studio'));
    });

    test('falls back to environment variables via configVar', () {
      final env = {
        'OMLX_BASE_URL': 'http://lan-mac:8080',
        'OMLX_API_KEY': 'token-from-omlx-env',
      };
      final plugin = omlx(configVar: (key) => env[key]);
      expect(plugin.clientManager.baseUrl, equals('http://lan-mac:8080'));
      expect(plugin.clientManager.apiKey, equals('token-from-omlx-env'));
    });

    test('does not read OPENAI_API_KEY when OMLX_API_KEY is absent', () {
      final env = {'OPENAI_API_KEY': 'token-from-openai-env'};
      final plugin = omlx(configVar: (key) => env[key]);
      expect(plugin.clientManager.apiKey, isNull);
    });

    test('creates typed model reference', () {
      final ref = omlx.model('qwen');
      expect(ref.name, equals('omlx/qwen'));
      expect(ref.customOptions, isNotNull);
    });

    test('creates typed model reference with custom namespace', () {
      final ref = omlx.model('qwen', namespace: 'omlx-studio');
      expect(ref.name, equals('omlx-studio/qwen'));
    });

    test('creates typed model reference with config', () {
      final ref = omlx.model(
        'qwen',
        config: OmlxGenerationConfig(temperature: 0.5),
      );
      expect(ref.name, equals('omlx/qwen'));
      expect(ref.config?.temperature, equals(0.5));
      expect(ref.customOptions, isNotNull);
    });

    test('creates typed embedder reference', () {
      final ref = omlx.embedder('bge-micro');
      expect(ref.name, equals('omlx/bge-micro'));
      expect(ref.customOptions, isNotNull);
    });

    test('creates typed embedder reference with custom namespace', () {
      final ref = omlx.embedder('bge-micro', namespace: 'omlx-studio');
      expect(ref.name, equals('omlx-studio/bge-micro'));
      expect(ref.customOptions, isNotNull);
    });

    test('creates typed speech model reference', () {
      final ref = omlx.speechModel(
        'kokoro',
        config: OmlxSpeechConfig(
          voice: 'af_heart',
          responseFormat: 'wav',
          speed: 1.1,
        ),
      );
      expect(ref.name, equals('omlx/kokoro'));
      expect(ref.config?.voice, equals('af_heart'));
      expect(ref.config?.responseFormat, equals('wav'));
      expect(ref.config?.speed, equals(1.1));
      expect(ref.customOptions, isNotNull);
    });

    test('creates typed speech model reference with custom namespace', () {
      final ref = omlx.speechModel('kokoro', namespace: 'omlx-studio');
      expect(ref.name, equals('omlx-studio/kokoro'));
      expect(ref.customOptions, isNotNull);
    });

    test('creates typed transcription model reference', () {
      final ref = omlx.transcriptionModel(
        'whisper',
        config: OmlxTranscriptionConfig(
          language: 'en',
          responseFormat: 'verbose_json',
          temperature: 0.0,
        ),
      );
      expect(ref.name, equals('omlx/whisper'));
      expect(ref.config?.language, equals('en'));
      expect(ref.config?.responseFormat, equals('verbose_json'));
      expect(ref.config?.temperature, equals(0.0));
      expect(ref.customOptions, isNotNull);
    });

    test('creates typed transcription model reference with custom namespace', () {
      final ref = omlx.transcriptionModel('whisper', namespace: 'omlx-studio');
      expect(ref.name, equals('omlx-studio/whisper'));
      expect(ref.customOptions, isNotNull);
    });
  });

  group('OmlxModelDefinition', () {
    test('defaults model to name when model is omitted', () {
      const def = OmlxModelDefinition(name: 'qwen-4bit');
      expect(def.name, equals('qwen-4bit'));
      expect(def.model, equals('qwen-4bit'));
      expect(def.supportsTools, isTrue);
      expect(def.supportsConstrainedOutput, isTrue);
      expect(def.supportsMedia, isTrue);
    });

    test('preserves distinct model identifier', () {
      const def = OmlxModelDefinition(
        name: 'qwen',
        model: 'mlx-community/Qwen2.5-7B-Instruct-4bit',
        supportsTools: false,
        supportsConstrainedOutput: false,
      );
      expect(def.name, equals('qwen'));
      expect(def.model, equals('mlx-community/Qwen2.5-7B-Instruct-4bit'));
      expect(def.supportsTools, isFalse);
      expect(def.supportsConstrainedOutput, isFalse);
    });
  });

  group('OmlxEmbedderDefinition', () {
    test('defaults model to name', () {
      const def = OmlxEmbedderDefinition(name: 'bge-micro', dimensions: 384);
      expect(def.name, equals('bge-micro'));
      expect(def.model, equals('bge-micro'));
      expect(def.dimensions, equals(384));
    });
  });
}
