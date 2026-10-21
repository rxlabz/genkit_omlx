import 'package:genkit/plugin.dart' as genkit;
import 'package:schemantic/schemantic.dart';

part 'transcription_config.g.dart';

/// Default transcription response format when none is specified.
const String defaultOmlxTranscriptionFormat = 'json';

/// Accepted transcription `response_format` values.
const List<String> transcriptionResponseFormats = [
  'json',
  'text',
  'srt',
  'verbose_json',
  'vtt',
];

const Map<String, String> _audioMimeExtensions = {
  'audio/flac': 'flac',
  'audio/x-flac': 'flac',
  'audio/mp4': 'mp4',
  'audio/mpeg': 'mp3',
  'audio/mp3': 'mp3',
  'audio/mpga': 'mpga',
  'audio/m4a': 'm4a',
  'audio/x-m4a': 'm4a',
  'audio/aac': 'aac',
  'audio/oga': 'oga',
  'audio/ogg': 'ogg',
  'audio/opus': 'ogg',
  'audio/wav': 'wav',
  'audio/x-wav': 'wav',
  'audio/wave': 'wav',
  'audio/webm': 'webm',
};

/// Resolves an upload filename with a recognized audio extension for [mimeType].
String audioFilenameFor(String mimeType) {
  final cleanMime = mimeType.split(';').first.trim().toLowerCase();
  final ext = _audioMimeExtensions[cleanMime];
  return ext == null ? 'input.wav' : 'input.$ext';
}

/// Infers an audio MIME type from a file path or extension, or returns `null`.
String? inferAudioMimeType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.mpga')) return 'audio/mpga';
  if (lower.endsWith('.m4a')) return 'audio/m4a';
  if (lower.endsWith('.mp4')) return 'audio/mp4';
  if (lower.endsWith('.flac')) return 'audio/flac';
  if (lower.endsWith('.ogg') || lower.endsWith('.oga')) return 'audio/ogg';
  if (lower.endsWith('.opus')) return 'audio/opus';
  if (lower.endsWith('.aac')) return 'audio/aac';
  if (lower.endsWith('.webm')) return 'audio/webm';
  return null;
}

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
@Schema(
  description: 'Request-time options for oMLX speech-to-text transcription models.',
)
abstract class $OmlxTranscriptionConfig {
  /// Optional wire model identifier override.
  String? get version;

  /// ISO-639-1 code of the spoken language (e.g. `'en'`, `'fr'`, `'es'`).
  String? get language;

  /// Optional vocabulary or style hint for the decoder.
  ///
  /// When unset, any accompanying text part in the request message is used.
  String? get prompt;

  /// Desired transcript format: `'json'` (default), `'text'`, `'srt'`,
  /// `'verbose_json'`, or `'vtt'`.
  @StringField(
    name: 'response_format',
    enumValues: ['json', 'text', 'srt', 'verbose_json', 'vtt'],
  )
  String? get responseFormat;

  /// Sampling temperature (`0.0` to `1.0`).
  @DoubleField(minimum: 0.0, maximum: 1.0)
  double? get temperature;
}

/// Returns the Schemantic type descriptor for [OmlxTranscriptionConfig].
SchemanticType<OmlxTranscriptionConfig> omlxTranscriptionConfigSchema() =>
    const _NormalizedOmlxTranscriptionConfigSchema();

/// Parses [OmlxTranscriptionConfig] from an action config map.
OmlxTranscriptionConfig parseOmlxTranscriptionConfig(
  Map<String, dynamic>? config,
) {
  if (config == null) return OmlxTranscriptionConfig();
  final normalized = normalizeOmlxTranscriptionConfig(config);
  return OmlxTranscriptionConfig.$schema.parse(normalized);
}

/// Normalizes camelCase and snake_case keys for [OmlxTranscriptionConfig].
Map<String, dynamic> normalizeOmlxTranscriptionConfig(
  Map<String, dynamic> raw,
) {
  final normalized = Map<String, dynamic>.from(raw);
  if (raw.containsKey('responseFormat') &&
      !raw.containsKey('response_format')) {
    normalized['response_format'] = raw['responseFormat'];
  }
  return normalized;
}

/// Validates request-time [OmlxTranscriptionConfig] values.
void validateOmlxTranscriptionConfig(OmlxTranscriptionConfig options) {
  final format = options.responseFormat;
  if (format != null && !transcriptionResponseFormats.contains(format)) {
    throw genkit.GenkitException(
      'Unknown responseFormat "$format". Accepted formats: '
      '${transcriptionResponseFormats.join(', ')}.',
      status: genkit.StatusCode.invalidArgument,
    );
  }

  final temp = options.temperature;
  if (temp != null && (temp < 0.0 || temp > 1.0)) {
    throw genkit.GenkitException(
      'temperature must be between 0.0 and 1.0; got $temp.',
      status: genkit.StatusCode.invalidArgument,
    );
  }
}

final class _NormalizedOmlxTranscriptionConfigSchema
    extends SchemanticType<OmlxTranscriptionConfig> {
  const _NormalizedOmlxTranscriptionConfigSchema();

  @override
  OmlxTranscriptionConfig parse(Object? json) {
    if (json == null) return OmlxTranscriptionConfig();
    if (json is! Map) return OmlxTranscriptionConfig();
    final normalized = normalizeOmlxTranscriptionConfig(
      json.cast<String, dynamic>(),
    );
    return OmlxTranscriptionConfig.$schema.parse(normalized);
  }

  @override
  JsonSchemaMetadata? get schemaMetadata =>
      OmlxTranscriptionConfig.$schema.schemaMetadata;

  @override
  Map<String, Object?> jsonSchema({bool useRefs = false}) =>
      OmlxTranscriptionConfig.$schema.jsonSchema(useRefs: useRefs);
}
