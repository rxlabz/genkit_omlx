// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embed_config.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

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
base class OmlxEmbedConfig {
  /// Creates a [OmlxEmbedConfig] from a JSON map.
  factory OmlxEmbedConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OmlxEmbedConfig._(this._json);

  OmlxEmbedConfig({int? dimensions, String? encodingFormat, String? user}) {
    _json = {
      'dimensions': ?dimensions,
      'encoding_format': ?encodingFormat,
      'user': ?user,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [OmlxEmbedConfig].
  static const SchemanticType<OmlxEmbedConfig> $schema =
      _OmlxEmbedConfigTypeFactory();

  /// Length of the returned vector.
  int? get dimensions {
    return (_json['dimensions'] as num?)?.toInt();
  }

  /// Length of the returned vector.
  set dimensions(int? value) {
    if (value == null) {
      _json.remove('dimensions');
    } else {
      _json['dimensions'] = value;
    }
  }

  /// Optional encoding format: "float" (default) or "base64".
  String? get encodingFormat {
    return _json['encoding_format'] as String?;
  }

  /// Optional encoding format: "float" (default) or "base64".
  set encodingFormat(String? value) {
    if (value == null) {
      _json.remove('encoding_format');
    } else {
      _json['encoding_format'] = value;
    }
  }

  /// Optional end-user identifier for request tracking.
  String? get user {
    return _json['user'] as String?;
  }

  /// Optional end-user identifier for request tracking.
  set user(String? value) {
    if (value == null) {
      _json.remove('user');
    } else {
      _json['user'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [OmlxEmbedConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _OmlxEmbedConfigTypeFactory extends SchemanticType<OmlxEmbedConfig> {
  const _OmlxEmbedConfigTypeFactory();

  @override
  OmlxEmbedConfig parse(Object? json) {
    return OmlxEmbedConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OmlxEmbedConfig',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Request-time embedding options for oMLX models.',
      'properties': <String, Object?>{
        'dimensions': <String, Object?>{'type': 'integer', 'minimum': 1},
        'encoding_format': <String, Object?>{
          'type': 'string',
          'enum': ['float', 'base64'],
        },
        'user': <String, Object?>{'type': 'string'},
      },
    },
    dependencies: [],
  );
}
