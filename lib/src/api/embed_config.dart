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

  /// Optional encoding format: "float" (default) or "base64".
  @StringField(name: 'encoding_format', enumValues: ['float', 'base64'])
  String? get encodingFormat;

  /// Optional end-user identifier for request tracking.
  String? get user;
}

/// Returns the Schemantic type descriptor for [OmlxEmbedConfig].
SchemanticType<OmlxEmbedConfig> omlxEmbedConfigSchema() =>
    const _NormalizedOmlxEmbedConfigSchema();

/// Parses [OmlxEmbedConfig] from an action options map.
OmlxEmbedConfig parseOmlxEmbedConfig(Map<String, dynamic>? config) {
  if (config == null) return OmlxEmbedConfig();
  final normalized = normalizeOmlxEmbedConfig(config);
  return OmlxEmbedConfig.$schema.parse(normalized);
}

/// Normalizes options for [OmlxEmbedConfig], handling snake_case aliases.
Map<String, dynamic> normalizeOmlxEmbedConfig(Map<String, dynamic> raw) {
  final normalized = Map<String, dynamic>.from(raw);
  if (raw.containsKey('encodingFormat') && !raw.containsKey('encoding_format')) {
    normalized['encoding_format'] = raw['encodingFormat'];
  }
  return normalized;
}

final class _NormalizedOmlxEmbedConfigSchema
    extends SchemanticType<OmlxEmbedConfig> {
  const _NormalizedOmlxEmbedConfigSchema();

  @override
  OmlxEmbedConfig parse(Object? json) {
    if (json == null) return OmlxEmbedConfig();
    if (json is! Map) return OmlxEmbedConfig();
    final normalized = normalizeOmlxEmbedConfig(json.cast<String, dynamic>());
    return OmlxEmbedConfig.$schema.parse(normalized);
  }

  @override
  JsonSchemaMetadata? get schemaMetadata =>
      OmlxEmbedConfig.$schema.schemaMetadata;

  @override
  Map<String, Object?> jsonSchema({bool useRefs = false}) =>
      OmlxEmbedConfig.$schema.jsonSchema(useRefs: useRefs);
}
