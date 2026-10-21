import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;

import '../core/client/omlx_client_manager.dart';
import '../integration/genkit/action_support.dart';
import '../integration/genkit/plugin.dart';
import 'embed_config.dart';
import 'embedder_definition.dart';
import 'generation_config.dart';
import 'model_definition.dart';

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
  /// - [baseUrl]: Base URL of the oMLX server (default: `http://localhost:8000`).
  /// - [apiKey]: Optional Bearer API key.
  /// - [models]: Optional list of statically declared model definitions.
  /// - [embedders]: Optional list of statically declared embedder definitions.
  /// - [httpClient]: Optional custom `http.Client` (useful for testing or proxying).
  /// - [timeout]: Request timeout (default: 120 seconds).
  /// - [defaultHeaders]: Headers attached to every outgoing request.
  OmlxPlugin call({
    String baseUrl = 'http://localhost:8000',
    String? apiKey,
    List<OmlxModelDefinition>? models,
    List<OmlxEmbedderDefinition>? embedders,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 120),
    Map<String, String> defaultHeaders = const {},
  }) {
    final clientManager = OmlxClientManager(
      baseUrl: baseUrl,
      apiKey: apiKey,
      httpClient: httpClient,
      timeout: timeout,
      defaultHeaders: defaultHeaders,
    );

    return OmlxPlugin(
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
    OmlxGenerationConfig? config,
  }) {
    return modelRef<OmlxGenerationConfig>(
      actionNameFor(name),
      config: config,
      customOptions: omlxGenerationConfigSchema(),
    );
  }

  /// Returns a typed Genkit embedder reference for [name].
  ///
  /// The [name] can be either a declared [OmlxEmbedderDefinition.name] or any
  /// embedding model supported by the oMLX server.
  EmbedderRef<OmlxEmbedConfig> embedder(String name) {
    return embedderRef<OmlxEmbedConfig>(
      actionNameFor(name),
      customOptions: omlxEmbedConfigSchema(),
    );
  }
}
