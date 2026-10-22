import 'package:schemantic/schemantic.dart';

part 'generation_config.g.dart';

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
@Schema(description: 'Request-time generation options for oMLX models.')
abstract class $OmlxGenerationConfig {
  /// Model identifier or quantization override (e.g. 'mlx-community/Qwen2.5-7B-Instruct-8bit').
  String? get version;

  /// Sampling temperature (0.0 - 2.0).
  @DoubleField(minimum: 0.0, maximum: 2.0)
  double? get temperature;

  /// Nucleus sampling probability cutoff (0.0 - 1.0).
  @DoubleField(minimum: 0.0, maximum: 1.0)
  double? get topP;

  /// Top-K sampling cutoff.
  @IntegerField(minimum: 1)
  int? get topK;

  /// Repetition penalty factor.
  @DoubleField(minimum: 0.0)
  double? get repetitionPenalty;

  /// Maximum tokens to generate.
  @IntegerField(minimum: 1)
  int? get maxTokens;

  /// Stop sequences.
  List<String>? get stop;

  /// Optional end-user identifier for request tracking.
  String? get user;

  /// Forces `{"type": "json_object"}` response format when output config is unconstrained.
  bool? get jsonMode;

  /// Whether to enforce strict JSON Schema validation (defaults to false).
  bool? get strictJsonSchema;

  /// Forces the model to call a specific tool function by name (using `ToolChoice.function(...)`).
  String? get toolChoiceFunction;

  /// Additional custom or vendor-specific oMLX parameters.
  Map<String, dynamic>? get extra;
}

/// Returns the Schemantic type descriptor for [OmlxGenerationConfig].
SchemanticType<OmlxGenerationConfig> omlxGenerationConfigSchema() =>
    const _NormalizedOmlxGenerationConfigSchema();

/// Parses [OmlxGenerationConfig] from an action options map.
OmlxGenerationConfig parseOmlxGenerationConfig(Map<String, dynamic>? config) {
  if (config == null) return OmlxGenerationConfig();
  final normalized = normalizeOmlxGenerationConfig(config);
  return OmlxGenerationConfig.$schema.parse(normalized);
}

/// Normalizes options for [OmlxGenerationConfig], handling snake_case aliases and unmodeled extra keys.
Map<String, dynamic> normalizeOmlxGenerationConfig(Map<String, dynamic> raw) {
  final knownKeys = {
    'version',
    'temperature',
    'topP',
    'top_p',
    'topK',
    'top_k',
    'repetitionPenalty',
    'repetition_penalty',
    'maxTokens',
    'max_tokens',
    'stop',
    'stopSequences',
    'user',
    'jsonMode',
    'json_mode',
    'strictJsonSchema',
    'strict_json_schema',
    'strict',
    'toolChoiceFunction',
    'tool_choice_function',
    'extra',
  };

  final normalized = <String, dynamic>{};
  final extraMap = <String, dynamic>{
    if (raw['extra'] is Map) ...(raw['extra'] as Map).cast<String, dynamic>(),
  };

  for (final entry in raw.entries) {
    if (!knownKeys.contains(entry.key)) {
      extraMap[entry.key] = entry.value;
      normalized[entry.key] = entry.value;
    }
  }

  if (raw.containsKey('version')) {
    normalized['version'] = raw['version']?.toString();
  }

  if (raw.containsKey('temperature')) {
    final temp = raw['temperature'];
    if (temp is num) normalized['temperature'] = temp.toDouble();
  }

  final topPVal = raw['topP'] ?? raw['top_p'];
  if (topPVal is num) {
    normalized['topP'] = topPVal.toDouble();
  }

  final topKVal = raw['topK'] ?? raw['top_k'];
  if (topKVal is num) {
    normalized['topK'] = topKVal.toInt();
  }

  final repVal = raw['repetitionPenalty'] ?? raw['repetition_penalty'];
  if (repVal is num) {
    normalized['repetitionPenalty'] = repVal.toDouble();
  }

  final maxTokVal = raw['maxTokens'] ?? raw['max_tokens'];
  if (maxTokVal is num) {
    normalized['maxTokens'] = maxTokVal.toInt();
  }

  final stopVal = raw['stop'] ?? raw['stopSequences'];
  if (stopVal is List) {
    normalized['stop'] = stopVal.cast<String>();
  } else if (stopVal is String) {
    normalized['stop'] = [stopVal];
  }

  if (raw.containsKey('user')) {
    normalized['user'] = raw['user']?.toString();
  }

  final jsonModeVal = raw['jsonMode'] ?? raw['json_mode'];
  if (jsonModeVal is bool) {
    normalized['jsonMode'] = jsonModeVal;
  }

  final strictVal =
      raw['strictJsonSchema'] ?? raw['strict_json_schema'] ?? raw['strict'];
  if (strictVal is bool) {
    normalized['strictJsonSchema'] = strictVal;
  }

  final toolChoiceFnVal =
      raw['toolChoiceFunction'] ?? raw['tool_choice_function'];
  if (toolChoiceFnVal is String && toolChoiceFnVal.isNotEmpty) {
    normalized['toolChoiceFunction'] = toolChoiceFnVal;
  }

  if (extraMap.isNotEmpty) {
    normalized['extra'] = extraMap;
  }

  return normalized;
}

final class _NormalizedOmlxGenerationConfigSchema
    extends SchemanticType<OmlxGenerationConfig> {
  const _NormalizedOmlxGenerationConfigSchema();

  @override
  OmlxGenerationConfig parse(Object? json) {
    if (json == null) return OmlxGenerationConfig();
    if (json is! Map) return OmlxGenerationConfig();
    final normalized = normalizeOmlxGenerationConfig(
      json.cast<String, dynamic>(),
    );
    return OmlxGenerationConfig.$schema.parse(normalized);
  }

  @override
  JsonSchemaMetadata? get schemaMetadata =>
      OmlxGenerationConfig.$schema.schemaMetadata;

  @override
  Map<String, Object?> jsonSchema({bool useRefs = false}) =>
      OmlxGenerationConfig.$schema.jsonSchema(useRefs: useRefs);
}
