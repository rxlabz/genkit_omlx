import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;

import '../core/client/omlx_client_manager.dart';
import '../integration/genkit/action_support.dart';
import '../integration/genkit/plugin.dart';
import 'embed_config.dart';
import 'embedder_definition.dart';
import 'generation_config.dart';
import 'model_definition.dart';
import 'speech_config.dart';
import 'transcription_config.dart';

/// Global handle used to configure and reference the `genkit_omlx` plugin.
///
/// ```dart
/// import 'package:genkit/genkit.dart';
/// import 'package:genkit_omlx/genkit_omlx.dart';
///
/// final plugin = omlx(
///   baseUrl: 'http://localhost:8000',
///   models: const [
///     OmlxModelDefinition(
///       name: 'qwen',
///       model: 'mlx-community/Qwen2.5-7B-Instruct-4bit',
///     ),
///   ],
/// );
///
/// final ai = Genkit(plugins: [plugin]);
/// final response = await ai.generate(
///   model: omlx.model('qwen'),
///   prompt: 'Explain continuous batching in simple terms.',
/// );
/// ```
const OmlxPluginHandle omlx = OmlxPluginHandle();

/// Factory and typed reference helper for the oMLX Genkit plugin.
class OmlxPluginHandle {
  /// Creates a plugin handle.
  const OmlxPluginHandle();

  /// Creates a configured [OmlxPlugin] instance.
  ///
  /// - [name]: Plugin and namespace identifier (default: [defaultOmlxNamespace], `'omlx'`).
  /// - [baseUrl]: Base URL of the oMLX server (defaults to `OMLX_BASE_URL` env var, or [defaultOmlxBaseUrl]).
  /// - [apiKey]: Optional Bearer API key (falls back to the `OMLX_API_KEY` env var).
  /// - [models]: Optional list of statically declared model definitions.
  /// - [embedders]: Optional list of statically declared embedder definitions.
  /// - [httpClient]: Optional custom `http.Client` (useful for testing or proxying).
  /// - [timeout]: Request timeout (default: 120 seconds).
  /// - [defaultHeaders]: Headers attached to every outgoing request.
  /// - [configVar]: Environment variable lookup function (defaults to [getConfigVar]).
  OmlxPlugin call({
    String name = defaultOmlxNamespace,
    String? baseUrl,
    String? apiKey,
    List<OmlxModelDefinition>? models,
    List<OmlxEmbedderDefinition>? embedders,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 120),
    Map<String, String> defaultHeaders = const {},
    String? Function(String name) configVar = getConfigVar,
  }) {
    final resolvedApiKey = apiKey ?? configVar('OMLX_API_KEY');
    final resolvedBaseUrl =
        baseUrl ?? configVar('OMLX_BASE_URL') ?? defaultOmlxBaseUrl;

    final clientManager = OmlxClientManager(
      baseUrl: resolvedBaseUrl,
      apiKey: resolvedApiKey,
      httpClient: httpClient,
      timeout: timeout,
      defaultHeaders: defaultHeaders,
    );

    return OmlxPlugin(
      name: name,
      clientManager: clientManager,
      models: models,
      embedders: embedders,
    );
  }

  /// Returns a typed Genkit model reference for [name].
  ///
  /// The [name] can be either a declared [OmlxModelDefinition.name] or any
  /// model identifier supported by the oMLX server.
  ModelRef<OmlxGenerationConfig> model(
    String name, {
    String namespace = defaultOmlxNamespace,
    OmlxGenerationConfig? config,
  }) {
    return modelRef<OmlxGenerationConfig>(
      actionNameFor(name, namespace: namespace),
      config: config,
      customOptions: omlxGenerationConfigSchema(),
    );
  }

  /// Returns a typed Genkit embedder reference for [name].
  ///
  /// The [name] can be either a declared [OmlxEmbedderDefinition.name] or any
  /// embedding model supported by the oMLX server.
  EmbedderRef<OmlxEmbedConfig> embedder(
    String name, {
    String namespace = defaultOmlxNamespace,
  }) {
    return embedderRef<OmlxEmbedConfig>(
      actionNameFor(name, namespace: namespace),
      customOptions: omlxEmbedConfigSchema(),
    );
  }

  /// Returns a typed Genkit text-to-speech model reference for [name]
  /// (`POST /v1/audio/speech`).
  ///
  /// Speech models accept text prompts and return a single audio [MediaPart]
  /// containing a base64 data URI.
  ModelRef<OmlxSpeechConfig> speechModel(
    String name, {
    String namespace = defaultOmlxNamespace,
    OmlxSpeechConfig? config,
  }) {
    return modelRef<OmlxSpeechConfig>(
      actionNameFor(name, namespace: namespace),
      config: config,
      customOptions: omlxSpeechConfigSchema(),
    );
  }

  /// Returns a typed Genkit speech-to-text transcription model reference for
  /// [name] (`POST /v1/audio/transcriptions`).
  ///
  /// Transcription models accept an audio [MediaPart] and return the transcript
  /// as a single [TextPart].
  ModelRef<OmlxTranscriptionConfig> transcriptionModel(
    String name, {
    String namespace = defaultOmlxNamespace,
    OmlxTranscriptionConfig? config,
  }) {
    return modelRef<OmlxTranscriptionConfig>(
      actionNameFor(name, namespace: namespace),
      config: config,
      customOptions: omlxTranscriptionConfigSchema(),
    );
  }
}
