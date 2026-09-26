/// Genkit integration for local models running on Apple Silicon through oMLX.
///
/// This package lets Genkit applications run models hosted on the [oMLX](https://github.com/jundot/omlx)
/// inference server, supporting streaming, tool calling, structured JSON output,
/// reasoning models (`<think>` blocks), and text embeddings.
///
/// Use [omlx] to:
///
/// - configure a plugin with server parameters and model definitions
/// - reference a registered or dynamically resolved model via `omlx.model(...)`
/// - reference an embedder via `omlx.embedder(...)`
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
///   prompt: 'Say hello in one short sentence.',
/// );
/// print(response.text);
/// ```
library;

export 'package:domlx/domlx.dart'
    show OmlxApiException, OmlxException, OmlxNetworkException;

export 'src/api/embed_config.dart' show OmlxEmbedConfig;
export 'src/api/embedder_definition.dart' show OmlxEmbedderDefinition;
export 'src/api/generation_config.dart' show OmlxGenerationConfig;
export 'src/api/model_definition.dart' show OmlxModelDefinition;
export 'src/api/plugin_handle.dart' show OmlxPluginHandle, omlx;
export 'src/integration/genkit/plugin.dart' show OmlxPlugin;
