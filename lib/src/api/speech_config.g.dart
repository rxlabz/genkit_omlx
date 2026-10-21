// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speech_config.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

/// Request-time options for oMLX text-to-speech (`POST /v1/audio/speech`) models.
///
/// ```dart
/// final response = await ai.generate(
///   model: omlx.speechModel('kokoro'),
///   prompt: 'Apple Silicon unified memory makes local inference fast.',
///   config: OmlxSpeechConfig(
///     voice: 'af_heart',
///     responseFormat: 'wav',
///     speed: 1.0,
///   ),
/// );
/// final audio = response.media; // data:audio/wav;base64,...
/// ```
base class OmlxSpeechConfig {
  /// Creates a [OmlxSpeechConfig] from a JSON map.
  factory OmlxSpeechConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OmlxSpeechConfig._(this._json);

  OmlxSpeechConfig({
    String? version,
    String? voice,
    String? responseFormat,
    double? speed,
  }) {
    _json = {
      'version': ?version,
      'voice': ?voice,
      'response_format': ?responseFormat,
      'speed': ?speed,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [OmlxSpeechConfig].
  static const SchemanticType<OmlxSpeechConfig> $schema =
      _OmlxSpeechConfigTypeFactory();

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

  /// Voice used to synthesize the audio (e.g. `'alloy'`, `'af_heart'`).
  ///
  /// Defaults to [defaultOmlxSpeechVoice] (`'alloy'`) when unset.
  String? get voice {
    return _json['voice'] as String?;
  }

  /// Voice used to synthesize the audio (e.g. `'alloy'`, `'af_heart'`).
  ///
  /// Defaults to [defaultOmlxSpeechVoice] (`'alloy'`) when unset.
  set voice(String? value) {
    if (value == null) {
      _json.remove('voice');
    } else {
      _json['voice'] = value;
    }
  }

  /// Audio container format for the generated speech. Defaults to `'mp3'`.
  String? get responseFormat {
    return _json['response_format'] as String?;
  }

  /// Audio container format for the generated speech. Defaults to `'mp3'`.
  set responseFormat(String? value) {
    if (value == null) {
      _json.remove('response_format');
    } else {
      _json['response_format'] = value;
    }
  }

  /// Playback speed multiplier (`0.25` to `4.0`).
  double? get speed {
    return (_json['speed'] as num?)?.toDouble();
  }

  /// Playback speed multiplier (`0.25` to `4.0`).
  set speed(double? value) {
    if (value == null) {
      _json.remove('speed');
    } else {
      _json['speed'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [OmlxSpeechConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _OmlxSpeechConfigTypeFactory
    extends SchemanticType<OmlxSpeechConfig> {
  const _OmlxSpeechConfigTypeFactory();

  @override
  OmlxSpeechConfig parse(Object? json) {
    return OmlxSpeechConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OmlxSpeechConfig',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Request-time options for oMLX text-to-speech models.',
      'properties': <String, Object?>{
        'version': <String, Object?>{'type': 'string'},
        'voice': <String, Object?>{'type': 'string'},
        'response_format': <String, Object?>{
          'type': 'string',
          'enum': ['mp3', 'opus', 'aac', 'flac', 'wav', 'pcm'],
        },
        'speed': <String, Object?>{
          'type': 'number',
          'minimum': 0.25,
          'maximum': 4.0,
        },
      },
    },
    dependencies: [],
  );
}
