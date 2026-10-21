import 'package:schemantic/schemantic.dart';

part 'embed_config.g.dart';

/// Request-time embedding options supported by `genkit_omlx`.
///
/// ```dart
/// final embeddings = await ai.embed(
///   embedder: omlx.embedder('bge-micro'),
///   document: DocumentData(
///     content: <Part>[TextPart(text: 'Apple Silicon UMA')],
///   ),
///   options: OmlxEmbedConfig(dimensions: 384),
/// );
/// ```
@Schema(description: 'Request-time embedding options for oMLX models.')
abstract class $OmlxEmbedConfig {
  /// Length of the returned vector.
  @IntegerField(minimum: 1)
  int? get dimensions;

  /// Optional end-user identifier for request tracking.
  String? get user;
}

/// Returns the Schemantic type descriptor for [OmlxEmbedConfig].
SchemanticType<OmlxEmbedConfig> omlxEmbedConfigSchema() =>
    OmlxEmbedConfig.$schema;

/// Parses [OmlxEmbedConfig] from an action options map.
OmlxEmbedConfig parseOmlxEmbedConfig(Map<String, dynamic>? config) {
  if (config == null) return OmlxEmbedConfig();
  return OmlxEmbedConfig.$schema.parse(config);
}
