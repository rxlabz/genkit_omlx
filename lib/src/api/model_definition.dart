import 'package:genkit/genkit.dart' show ModelInfo;

import '../integration/genkit/action_support.dart' show OmlxModelKind;

/// Static configuration for an oMLX model registered with Genkit.
///
/// Each definition specifies the Genkit action name, the underlying oMLX
/// model identifier, and capability flags for tooling, structured output,
/// and media support.
///
/// ```dart
/// const qwenModel = OmlxModelDefinition(
///   name: 'qwen',
///   model: 'mlx-community/Qwen2.5-7B-Instruct-4bit',
///   supportsTools: true,
///   supportsConstrainedOutput: true,
/// );
/// ```
class OmlxModelDefinition {
  /// Creates a definition for an oMLX model.
  ///
  /// If [model] is not provided, [name] is used as the model identifier.
  const OmlxModelDefinition({
    required this.name,
    String? model,
    this.kind,
    this.supportsTools = true,
    this.supportsConstrainedOutput = true,
    this.supportsMedia = true,
    this.modelInfo,
  }) : model = model ?? name,
       assert(name != '', 'Model name must not be empty.');

  /// Unique name used when registering in Genkit (e.g. `omlx/<name>`).
  final String name;

  /// Underlying model identifier passed to oMLX (e.g. `mlx-community/Qwen2.5-7B-Instruct-4bit`).
  final String model;

  /// Optional explicit model kind override when the model name does not follow
  /// standard naming conventions.
  final OmlxModelKind? kind;

  /// Whether this model accepts Genkit tool requests.
  final bool supportsTools;

  /// Whether this model supports constrained JSON Schema output generation.
  final bool supportsConstrainedOutput;

  /// Whether this model accepts multimodal media parts (e.g. images).
  final bool supportsMedia;

  /// Optional Genkit [ModelInfo] metadata override.
  final ModelInfo? modelInfo;
}
