import 'package:genkit/genkit.dart' show ModelInfo;

/// Static configuration for an oMLX embedding model registered with Genkit.
///
/// ```dart
/// const embedder = OmlxEmbedderDefinition(
///   name: 'bge-micro',
///   model: 'bge-micro',
///   dimensions: 384,
/// );
/// ```
class OmlxEmbedderDefinition {
  /// Creates an embedder definition.
  ///
  /// If [model] is omitted, [name] is used as the model identifier.
  const OmlxEmbedderDefinition({
    required this.name,
    String? model,
    this.dimensions,
    this.modelInfo,
  }) : model = model ?? name,
       assert(name != '', 'Embedder name must not be empty.');

  /// Unique name used when registering in Genkit (e.g. `omlx/<name>`).
  final String name;

  /// Underlying model identifier passed to oMLX.
  final String model;

  /// Output vector dimensions, if known.
  final int? dimensions;

  /// Optional Genkit [ModelInfo] metadata override.
  final ModelInfo? modelInfo;
}
