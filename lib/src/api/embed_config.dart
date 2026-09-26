import 'config_parsing.dart';

/// Request-time embedding options supported by `genkit_omlx`.
///
/// ```dart
/// final embeddings = await ai.embed(
///   embedder: omlx.embedder('bge-micro'),
///   document: DocumentData(
///     content: <Part>[TextPart(text: 'Apple Silicon UMA')],
///   ),
///   options: const OmlxEmbedConfig(dimensions: 384),
/// );
/// ```
class OmlxEmbedConfig {
  /// Optional dimension cutoff if supported by the model.
  final int? dimensions;

  /// Optional encoding format: "float" (default) or "base64".
  final String? encodingFormat;

  /// Optional end-user identifier.
  final String? user;

  /// Creates an embedding configuration.
  const OmlxEmbedConfig({this.dimensions, this.encodingFormat, this.user});

  /// Builds a config instance from a Genkit options map.
  factory OmlxEmbedConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const OmlxEmbedConfig();
    }

    return OmlxEmbedConfig(
      dimensions: asInt(json['dimensions']),
      encodingFormat:
          json['encodingFormat'] as String? ??
          json['encoding_format'] as String?,
      user: json['user'] as String?,
    );
  }

  /// Serializes the config to a map.
  Map<String, dynamic> toJson() {
    return {
      if (dimensions != null) 'dimensions': dimensions,
      if (encodingFormat != null) 'encoding_format': encodingFormat,
      if (user != null) 'user': user,
    };
  }
}
