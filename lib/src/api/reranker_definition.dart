import 'package:genkit/genkit.dart' show ActionType, ModelInfo;
import 'package:schemantic/schemantic.dart';

/// Action type identifier used when registering and resolving oMLX rerankers in Genkit.
const ActionType omlxRerankerActionType = ActionType('reranker');

/// Static configuration for an oMLX reranker model registered with Genkit.
///
/// ```dart
/// const bgeReranker = OmlxRerankerDefinition(
///   name: 'bge-reranker',
///   model: 'BAAI/bge-reranker-v2-m3',
/// );
/// ```
class OmlxRerankerDefinition {
  /// Creates a definition for an oMLX reranker model.
  ///
  /// If [model] is not provided, [name] is used as the model identifier.
  const OmlxRerankerDefinition({
    required this.name,
    String? model,
    this.modelInfo,
  }) : model = model ?? name,
       assert(name != '', 'Reranker name must not be empty.');

  /// Unique name used when registering in Genkit (e.g. `omlx/<name>`).
  final String name;

  /// Underlying model identifier passed to oMLX (e.g. `BAAI/bge-reranker-v2-m3`).
  final String model;

  /// Optional Genkit [ModelInfo] metadata override.
  final ModelInfo? modelInfo;
}

/// Typed reference to an oMLX reranker action.
class OmlxRerankerRef<CustomOptions> {
  /// Creates a reference to an oMLX reranker action.
  const OmlxRerankerRef(
    this.name, {
    this.config,
    this.customOptions,
  });

  /// Fully-qualified action name (e.g. `'omlx/BAAI/bge-reranker-v2-m3'`).
  final String name;

  /// Optional default options attached to this reference.
  final CustomOptions? config;

  /// Schemantic schema describing the reranker's custom options.
  final SchemanticType<CustomOptions>? customOptions;
}
