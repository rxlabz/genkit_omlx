import 'package:genkit/plugin.dart' as genkit;
import 'package:schemantic/schemantic.dart';

part 'speech_config.g.dart';

/// Default audio container format when none is specified.
const String defaultOmlxSpeechFormat = 'mp3';

/// Default voice identifier when none is specified.
const String defaultOmlxSpeechVoice = 'alloy';

/// Maps an oMLX speech `response_format` to the MIME type used on the returned
/// [genkit.MediaPart].
const Map<String, String> speechResponseFormatMediaTypes = {
  'mp3': 'audio/mpeg',
  'opus': 'audio/ogg',
  'aac': 'audio/aac',
  'flac': 'audio/flac',
  'wav': 'audio/wav',
  'pcm': 'audio/pcm',
};

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
@Schema(description: 'Request-time options for oMLX text-to-speech models.')
abstract class $OmlxSpeechConfig {
  /// Optional wire model identifier override.
  String? get version;

  /// Voice used to synthesize the audio (e.g. `'alloy'`, `'af_heart'`).
  ///
  /// Defaults to [defaultOmlxSpeechVoice] (`'alloy'`) when unset.
  String? get voice;

  /// Audio container format for the generated speech. Defaults to `'mp3'`.
  @StringField(
    name: 'response_format',
    enumValues: ['mp3', 'opus', 'aac', 'flac', 'wav', 'pcm'],
  )
  String? get responseFormat;

  /// Playback speed multiplier (`0.25` to `4.0`).
  @DoubleField(minimum: 0.25, maximum: 4.0)
  double? get speed;
}

/// Returns the Schemantic type descriptor for [OmlxSpeechConfig].
SchemanticType<OmlxSpeechConfig> omlxSpeechConfigSchema() =>
    const _NormalizedOmlxSpeechConfigSchema();

/// Parses [OmlxSpeechConfig] from an action config map.
OmlxSpeechConfig parseOmlxSpeechConfig(Map<String, dynamic>? config) {
  if (config == null) return OmlxSpeechConfig();
  final normalized = normalizeOmlxSpeechConfig(config);
  return OmlxSpeechConfig.$schema.parse(normalized);
}

/// Normalizes camelCase and snake_case keys for [OmlxSpeechConfig].
Map<String, dynamic> normalizeOmlxSpeechConfig(Map<String, dynamic> raw) {
  final normalized = Map<String, dynamic>.from(raw);
  if (raw.containsKey('responseFormat') &&
      !raw.containsKey('response_format')) {
    normalized['response_format'] = raw['responseFormat'];
  }
  return normalized;
}

/// Validates request-time [OmlxSpeechConfig] values.
void validateOmlxSpeechConfig(OmlxSpeechConfig options) {
  final format = options.responseFormat;
  if (format != null && !speechResponseFormatMediaTypes.containsKey(format)) {
    throw genkit.GenkitException(
      'Unknown responseFormat "$format". Accepted formats: '
      '${speechResponseFormatMediaTypes.keys.join(', ')}.',
      status: genkit.StatusCode.invalidArgument,
    );
  }

  final speed = options.speed;
  if (speed != null && (speed < 0.25 || speed > 4.0)) {
    throw genkit.GenkitException(
      'speed must be between 0.25 and 4.0; got $speed.',
      status: genkit.StatusCode.invalidArgument,
    );
  }
}

final class _NormalizedOmlxSpeechConfigSchema
    extends SchemanticType<OmlxSpeechConfig> {
  const _NormalizedOmlxSpeechConfigSchema();

  @override
  OmlxSpeechConfig parse(Object? json) {
    if (json == null) return OmlxSpeechConfig();
    if (json is! Map) return OmlxSpeechConfig();
    final normalized = normalizeOmlxSpeechConfig(json.cast<String, dynamic>());
    return OmlxSpeechConfig.$schema.parse(normalized);
  }

  @override
  JsonSchemaMetadata? get schemaMetadata =>
      OmlxSpeechConfig.$schema.schemaMetadata;

  @override
  Map<String, Object?> jsonSchema({bool useRefs = false}) =>
      OmlxSpeechConfig.$schema.jsonSchema(useRefs: useRefs);
}
