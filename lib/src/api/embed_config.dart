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
  /// Optional wire model identifier override (e.g. `'BAAI/bge-m3'`).
  String? get version;

  /// Length of the returned vector.
  @IntegerField(minimum: 1)
  int? get dimensions;

  /// Optional encoding format for the returned embeddings (`'float'` or `'base64'`).
  @StringField(
    name: 'encoding_format',
    enumValues: ['float', 'base64'],
  )
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
  return OmlxEmbedConfig.$schema.parse(normalizeOmlxEmbedConfig(config));
}

/// Normalizes camelCase and snake_case keys for [OmlxEmbedConfig].
Map<String, dynamic> normalizeOmlxEmbedConfig(Map<String, dynamic> raw) {
  final normalized = Map<String, dynamic>.from(raw);
  if (raw.containsKey('encodingFormat') &&
      !raw.containsKey('encoding_format')) {
    normalized['encoding_format'] = raw['encodingFormat'];
  }
  return normalized;
}

final class _NormalizedOmlxEmbedConfigSchema
    extends SchemanticType<OmlxEmbedConfig> {
  const _NormalizedOmlxEmbedConfigSchema();

  @override
  OmlxEmbedConfig parse(Object? json) {
    if (json == null || json is! Map) return OmlxEmbedConfig();
    return OmlxEmbedConfig.$schema.parse(
      normalizeOmlxEmbedConfig(json.cast<String, dynamic>()),
    );
  }

  @override
  JsonSchemaMetadata? get schemaMetadata =>
      OmlxEmbedConfig.$schema.schemaMetadata;

  @override
  Map<String, Object?> jsonSchema({bool useRefs = false}) =>
      OmlxEmbedConfig.$schema.jsonSchema(useRefs: useRefs);
}
