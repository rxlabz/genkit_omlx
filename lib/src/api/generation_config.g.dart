// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'generation_config.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

/// Request-time generation options supported by `genkit_omlx`.
///
/// ```dart
/// final response = await ai.generate(
///   model: omlx.model('mlx-community/Qwen2.5-7B-Instruct-4bit'),
///   prompt: 'Summarize continuous batching.',
///   config: OmlxGenerationConfig(
///     temperature: 0.7,
///     topP: 0.9,
///     maxTokens: 512,
///   ),
/// );
/// ```
base class OmlxGenerationConfig {
  /// Creates a [OmlxGenerationConfig] from a JSON map.
  factory OmlxGenerationConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OmlxGenerationConfig._(this._json);

  OmlxGenerationConfig({
    String? version,
    double? temperature,
    double? topP,
    int? topK,
    double? repetitionPenalty,
    int? maxTokens,
    List<String>? stop,
    String? user,
    bool? jsonMode,
    bool? strictJsonSchema,
    Map<String, dynamic>? extra,
  }) {
    _json = {
      'version': ?version,
      'temperature': ?temperature,
      'topP': ?topP,
      'topK': ?topK,
      'repetitionPenalty': ?repetitionPenalty,
      'maxTokens': ?maxTokens,
      'stop': ?stop,
      'user': ?user,
      'jsonMode': ?jsonMode,
      'strictJsonSchema': ?strictJsonSchema,
      'extra': ?extra,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [OmlxGenerationConfig].
  static const SchemanticType<OmlxGenerationConfig> $schema =
      _OmlxGenerationConfigTypeFactory();

  /// Model identifier or quantization override (e.g. 'mlx-community/Qwen2.5-7B-Instruct-8bit').
  String? get version {
    return _json['version'] as String?;
  }

  /// Model identifier or quantization override (e.g. 'mlx-community/Qwen2.5-7B-Instruct-8bit').
  set version(String? value) {
    if (value == null) {
      _json.remove('version');
    } else {
      _json['version'] = value;
    }
  }

  /// Sampling temperature (0.0 - 2.0).
  double? get temperature {
    return (_json['temperature'] as num?)?.toDouble();
  }

  /// Sampling temperature (0.0 - 2.0).
  set temperature(double? value) {
    if (value == null) {
      _json.remove('temperature');
    } else {
      _json['temperature'] = value;
    }
  }

  /// Nucleus sampling probability cutoff (0.0 - 1.0).
  double? get topP {
    return (_json['topP'] as num?)?.toDouble();
  }

  /// Nucleus sampling probability cutoff (0.0 - 1.0).
  set topP(double? value) {
    if (value == null) {
      _json.remove('topP');
    } else {
      _json['topP'] = value;
    }
  }

  /// Top-K sampling cutoff.
  int? get topK {
    return (_json['topK'] as num?)?.toInt();
  }

  /// Top-K sampling cutoff.
  set topK(int? value) {
    if (value == null) {
      _json.remove('topK');
    } else {
      _json['topK'] = value;
    }
  }

  /// Repetition penalty factor.
  double? get repetitionPenalty {
    return (_json['repetitionPenalty'] as num?)?.toDouble();
  }

  /// Repetition penalty factor.
  set repetitionPenalty(double? value) {
    if (value == null) {
      _json.remove('repetitionPenalty');
    } else {
      _json['repetitionPenalty'] = value;
    }
  }

  /// Maximum tokens to generate.
  int? get maxTokens {
    return (_json['maxTokens'] as num?)?.toInt();
  }

  /// Maximum tokens to generate.
  set maxTokens(int? value) {
    if (value == null) {
      _json.remove('maxTokens');
    } else {
      _json['maxTokens'] = value;
    }
  }

  /// Stop sequences.
  List<String>? get stop {
    return (_json['stop'] as List?)?.cast<String>();
  }

  /// Stop sequences.
  set stop(List<String>? value) {
    if (value == null) {
      _json.remove('stop');
    } else {
      _json['stop'] = value;
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

  /// Forces `{"type": "json_object"}` response format when output config is unconstrained.
  bool? get jsonMode {
    return _json['jsonMode'] as bool?;
  }

  /// Forces `{"type": "json_object"}` response format when output config is unconstrained.
  set jsonMode(bool? value) {
    if (value == null) {
      _json.remove('jsonMode');
    } else {
      _json['jsonMode'] = value;
    }
  }

  /// Whether to enforce strict JSON Schema validation (defaults to false).
  bool? get strictJsonSchema {
    return _json['strictJsonSchema'] as bool?;
  }

  /// Whether to enforce strict JSON Schema validation (defaults to false).
  set strictJsonSchema(bool? value) {
    if (value == null) {
      _json.remove('strictJsonSchema');
    } else {
      _json['strictJsonSchema'] = value;
    }
  }

  /// Additional custom or vendor-specific oMLX parameters.
  Map<String, dynamic>? get extra {
    return (_json['extra'] as Map?)?.cast<String, dynamic>();
  }

  /// Additional custom or vendor-specific oMLX parameters.
  set extra(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('extra');
    } else {
      _json['extra'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [OmlxGenerationConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _OmlxGenerationConfigTypeFactory
    extends SchemanticType<OmlxGenerationConfig> {
  const _OmlxGenerationConfigTypeFactory();

  @override
  OmlxGenerationConfig parse(Object? json) {
    return OmlxGenerationConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OmlxGenerationConfig',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Request-time generation options for oMLX models.',
      'properties': <String, Object?>{
        'version': <String, Object?>{'type': 'string'},
        'temperature': <String, Object?>{
          'type': 'number',
          'minimum': 0.0,
          'maximum': 2.0,
        },
        'topP': <String, Object?>{
          'type': 'number',
          'minimum': 0.0,
          'maximum': 1.0,
        },
        'topK': <String, Object?>{'type': 'integer', 'minimum': 1},
        'repetitionPenalty': <String, Object?>{
          'type': 'number',
          'minimum': 0.0,
        },
        'maxTokens': <String, Object?>{'type': 'integer', 'minimum': 1},
        'stop': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'string'},
        },
        'user': <String, Object?>{'type': 'string'},
        'jsonMode': <String, Object?>{'type': 'boolean'},
        'strictJsonSchema': <String, Object?>{'type': 'boolean'},
        'extra': <String, Object?>{
          'type': 'object',
          'additionalProperties': <String, Object?>{},
        },
      },
    },
    dependencies: [],
  );
}
