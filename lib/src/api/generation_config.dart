import 'config_parsing.dart';

/// Request-time generation options supported by `genkit_omlx`.
///
/// ```dart
/// final response = await ai.generate(
///   model: omlx.model('mlx-community/Qwen2.5-7B-Instruct-4bit'),
///   prompt: 'Summarize continuous batching.',
///   config: const OmlxGenerationConfig(
///     temperature: 0.7,
///     topP: 0.9,
///     maxTokens: 512,
///   ),
/// );
/// ```
class OmlxGenerationConfig {
  /// Sampling temperature (default 1.0 in oMLX).
  final double? temperature;

  /// Nucleus sampling probability cutoff (0.0 - 1.0).
  final double? topP;

  /// Top-K sampling cutoff.
  final int? topK;

  /// Repetition penalty factor.
  final double? repetitionPenalty;

  /// Maximum tokens to generate.
  final int? maxTokens;

  /// Stop sequences.
  final List<String>? stop;

  /// Optional end-user identifier for request tracking.
  final String? user;

  /// Additional custom or vendor-specific oMLX parameters.
  final Map<String, dynamic>? extra;

  /// Creates a generation configuration.
  const OmlxGenerationConfig({
    this.temperature,
    this.topP,
    this.topK,
    this.repetitionPenalty,
    this.maxTokens,
    this.stop,
    this.user,
    this.extra,
  });

  /// Builds a config instance from a Genkit options map.
  factory OmlxGenerationConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const OmlxGenerationConfig();
    }

    final knownKeys = {
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
      'extra',
    };

    final extraMap = <String, dynamic>{
      if (json['extra'] is Map)
        ...(json['extra'] as Map).cast<String, dynamic>(),
      for (final entry in json.entries)
        if (!knownKeys.contains(entry.key)) entry.key: entry.value,
    };

    return OmlxGenerationConfig(
      temperature: asDouble(json['temperature']),
      topP: asDouble(json['topP'] ?? json['top_p']),
      topK: asInt(json['topK'] ?? json['top_k']),
      repetitionPenalty: asDouble(
        json['repetitionPenalty'] ?? json['repetition_penalty'],
      ),
      maxTokens: asInt(json['maxTokens'] ?? json['max_tokens']),
      stop: asStringList(json['stop'] ?? json['stopSequences']),
      user: json['user'] as String?,
      extra: extraMap.isEmpty ? null : extraMap,
    );
  }

  /// Serializes the config to a map compatible with Genkit and oMLX.
  Map<String, dynamic> toJson() {
    return {
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (topK != null) 'top_k': topK,
      if (repetitionPenalty != null) 'repetition_penalty': repetitionPenalty,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (stop != null) 'stop': stop,
      if (user != null) 'user': user,
      ...?extra,
    };
  }
}
