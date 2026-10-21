// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcription_config.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

/// Request-time options for oMLX speech-to-text (`POST /v1/audio/transcriptions`) models.
///
/// ```dart
/// final response = await ai.generate(
///   model: omlx.transcriptionModel('mlx-community/whisper-large-v3-turbo'),
///   promptParts: [
///     MediaPart(
///       media: Media(
///         contentType: 'audio/wav',
///         url: 'data:audio/wav;base64,...',
///       ),
///     ),
///   ],
///   config: OmlxTranscriptionConfig(language: 'en'),
/// );
/// print(response.text);
/// ```
base class OmlxTranscriptionConfig {
  /// Creates a [OmlxTranscriptionConfig] from a JSON map.
  factory OmlxTranscriptionConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OmlxTranscriptionConfig._(this._json);

  OmlxTranscriptionConfig({
    String? version,
    String? language,
    String? prompt,
    String? responseFormat,
    double? temperature,
  }) {
    _json = {
      'version': ?version,
      'language': ?language,
      'prompt': ?prompt,
      'response_format': ?responseFormat,
      'temperature': ?temperature,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [OmlxTranscriptionConfig].
  static const SchemanticType<OmlxTranscriptionConfig> $schema =
      _OmlxTranscriptionConfigTypeFactory();

  /// Optional wire model identifier override.
  String? get version {
    return _json['version'] as String?;
  }

  /// Optional wire model identifier override.
  set version(String? value) {
    if (value == null) {
      _json.remove('version');
    } else {
      _json['version'] = value;
    }
  }

  /// ISO-639-1 code of the spoken language (e.g. `'en'`, `'fr'`, `'es'`).
  String? get language {
    return _json['language'] as String?;
  }

  /// ISO-639-1 code of the spoken language (e.g. `'en'`, `'fr'`, `'es'`).
  set language(String? value) {
    if (value == null) {
      _json.remove('language');
    } else {
      _json['language'] = value;
    }
  }

  /// Optional vocabulary or style hint for the decoder.
  ///
  /// When unset, any accompanying text part in the request message is used.
  String? get prompt {
    return _json['prompt'] as String?;
  }

  /// Optional vocabulary or style hint for the decoder.
  ///
  /// When unset, any accompanying text part in the request message is used.
  set prompt(String? value) {
    if (value == null) {
      _json.remove('prompt');
    } else {
      _json['prompt'] = value;
    }
  }

  /// Desired transcript format: `'json'` (default), `'text'`, `'srt'`,
  /// `'verbose_json'`, or `'vtt'`.
  String? get responseFormat {
    return _json['response_format'] as String?;
  }

  /// Desired transcript format: `'json'` (default), `'text'`, `'srt'`,
  /// `'verbose_json'`, or `'vtt'`.
  set responseFormat(String? value) {
    if (value == null) {
      _json.remove('response_format');
    } else {
      _json['response_format'] = value;
    }
  }

  /// Sampling temperature (`0.0` to `1.0`).
  double? get temperature {
    return (_json['temperature'] as num?)?.toDouble();
  }

  /// Sampling temperature (`0.0` to `1.0`).
  set temperature(double? value) {
    if (value == null) {
      _json.remove('temperature');
    } else {
      _json['temperature'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [OmlxTranscriptionConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _OmlxTranscriptionConfigTypeFactory
    extends SchemanticType<OmlxTranscriptionConfig> {
  const _OmlxTranscriptionConfigTypeFactory();

  @override
  OmlxTranscriptionConfig parse(Object? json) {
    return OmlxTranscriptionConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OmlxTranscriptionConfig',
    definition: <String, Object?>{
      'type': 'object',
      'description':
          'Request-time options for oMLX speech-to-text transcription models.',
      'properties': <String, Object?>{
        'version': <String, Object?>{'type': 'string'},
        'language': <String, Object?>{'type': 'string'},
        'prompt': <String, Object?>{'type': 'string'},
        'response_format': <String, Object?>{
          'type': 'string',
          'enum': ['json', 'text', 'srt', 'verbose_json', 'vtt'],
        },
        'temperature': <String, Object?>{
          'type': 'number',
          'minimum': 0.0,
          'maximum': 1.0,
        },
      },
    },
    dependencies: [],
  );
}
