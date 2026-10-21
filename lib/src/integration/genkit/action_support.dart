import 'package:genkit/plugin.dart' as genkit;

import '../../api/embed_config.dart';
import '../../api/embedder_definition.dart';
import '../../api/generation_config.dart';
import '../../api/model_definition.dart';
import '../../api/rerank_config.dart';
import '../../api/reranker_definition.dart';
import '../../api/speech_config.dart';
import '../../api/transcription_config.dart';

/// Default plugin / namespace name used when no custom name is provided.
const String defaultOmlxNamespace = 'omlx';

/// Default base URL of the local oMLX server.
const String defaultOmlxBaseUrl = 'http://localhost:8000';

/// Legacy alias for [defaultOmlxNamespace].
const String omlxPluginName = defaultOmlxNamespace;

/// Formats a model or embedder name into an action name (e.g. `omlx/<name>`).
String actionNameFor(String name, {String namespace = defaultOmlxNamespace}) =>
    '$namespace/$name';

/// Identifies the modality or API endpoint serving an oMLX model.
///
/// Defined as a `final class` rather than an enum so adding new model kinds
/// in future releases does not break exhaustive switches in caller code.
final class OmlxModelKind {
  const OmlxModelKind._(this._name);

  final String _name;

  /// Chat completions (`POST /v1/chat/completions`).
  static const OmlxModelKind chat = OmlxModelKind._('chat');

  /// Text embeddings (`POST /v1/embeddings`).
  static const OmlxModelKind embedding = OmlxModelKind._('embedding');

  /// Text-to-speech (`POST /v1/audio/speech`).
  static const OmlxModelKind speech = OmlxModelKind._('speech');

  /// Speech-to-text (`POST /v1/audio/transcriptions`).
  static const OmlxModelKind transcription = OmlxModelKind._('transcription');

  /// Document reranking (`POST /v1/rerank`).
  static const OmlxModelKind rerank = OmlxModelKind._('rerank');

  @override
  String toString() => 'OmlxModelKind.$_name';
}

final RegExp _boundedEmbedFamilyPattern = RegExp(
  r'(^|[/\-_.])(bge|gte|e5)([/\-_.]|$)',
);

final RegExp _boundedSpeechFamilyPattern = RegExp(
  r'(^|[/\-_.])(bark|csm)([/\-_.]|$)',
);

final RegExp _boundedTranscriptionFamilyPattern = RegExp(
  r'(^|[/\-_.])(canary)([/\-_.]|$)',
);

/// Classifies a model identifier (and optional raw `/v1/models` metadata) into
/// an [OmlxModelKind].
///
/// Classification uses two tiers:
/// 1. **Explicit Server Metadata**: Inspects `type`, `model_type`,
///    `engine_type`, `task`, `pipeline_tag`, and `modality` in [raw] when
///    present.
/// 2. **Boundary-Aware Name Heuristics**:
///    - Rerankers (`rerank`, `cross-encoder`) are checked **before**
///      embeddings so models like `bge-reranker-v2-m3` or `gte-reranker` are
///      not misclassified as embedders.
///    - Short family tokens (`bge`, `gte`, `e5`, `bark`, `csm`, `canary`) are
///      matched on delimiter boundaries (`/`, `-`, `_`, `.`) to avoid substring
///      collisions with commit hashes or quantization tags (e.g. `e5a1`).
OmlxModelKind classifyModel(String modelId, {Map<String, dynamic>? raw}) {
  if (raw != null && raw.isNotEmpty) {
    final explicitKind = _classifyFromMetadata(raw);
    if (explicitKind != null) {
      return explicitKind;
    }
  }

  final id = modelId.toLowerCase();

  // 1. Rerankers (must run before embedding family checks for bge/gte-reranker)
  if (id.contains('rerank') || id.contains('cross-encoder')) {
    return OmlxModelKind.rerank;
  }

  // 2. Speech / TTS
  if (id.contains('tts') ||
      id.contains('kokoro') ||
      id.contains('cosyvoice') ||
      id.contains('orpheus') ||
      id.contains('outetts') ||
      _boundedSpeechFamilyPattern.hasMatch(id)) {
    return OmlxModelKind.speech;
  }

  // 3. Transcription / STT
  if (id.contains('whisper') ||
      id.contains('transcribe') ||
      id.contains('parakeet') ||
      id.contains('sensevoice') ||
      id.contains('moonshine') ||
      id.contains('voxtral') ||
      _boundedTranscriptionFamilyPattern.hasMatch(id)) {
    return OmlxModelKind.transcription;
  }

  // 4. Embeddings
  if (id.contains('embed') ||
      id.contains('minilm') ||
      _boundedEmbedFamilyPattern.hasMatch(id)) {
    return OmlxModelKind.embedding;
  }

  return OmlxModelKind.chat;
}

OmlxModelKind? _classifyFromMetadata(Map<String, dynamic> raw) {
  const keys = [
    'type',
    'model_type',
    'engine_type',
    'task',
    'pipeline_tag',
    'modality',
  ];

  for (final key in keys) {
    final value = raw[key];
    if (value is! String || value.isEmpty) continue;
    final normalized = value.toLowerCase().trim();

    switch (normalized) {
      case 'rerank':
      case 'reranker':
      case 'text-ranking':
      case 'cross-encoder':
        return OmlxModelKind.rerank;
      case 'embedding':
      case 'embeddings':
      case 'embed':
      case 'feature-extraction':
      case 'sentence-similarity':
        return OmlxModelKind.embedding;
      case 'tts':
      case 'speech':
      case 'text-to-speech':
      case 'text_to_speech':
      case 'audio-generation':
        return OmlxModelKind.speech;
      case 'stt':
      case 'transcription':
      case 'asr':
      case 'speech-to-text':
      case 'speech_to_text':
      case 'automatic-speech-recognition':
      case 'whisper':
        return OmlxModelKind.transcription;
      case 'chat':
      case 'llm':
      case 'vlm':
      case 'text-generation':
      case 'image-text-to-text':
      case 'causal-lm':
        return OmlxModelKind.chat;
    }
  }

  return null;
}

/// Returns `true` when [info] declares exclusive media output (`output: ['media']`).
bool declaresExclusiveMediaOutput(genkit.ModelInfo? info) {
  final output = info?.supports?['output'];
  return output is List && output.length == 1 && output.first == 'media';
}

/// Resolves the effective [OmlxModelKind] for an [OmlxModelDefinition].
OmlxModelKind resolveModelKind(
  OmlxModelDefinition definition, {
  Map<String, dynamic>? raw,
}) {
  if (definition.kind != null) {
    return definition.kind!;
  }
  if (declaresExclusiveMediaOutput(definition.modelInfo)) {
    return OmlxModelKind.speech;
  }
  final byModel = classifyModel(definition.model, raw: raw);
  if (byModel != OmlxModelKind.chat) {
    return byModel;
  }
  return classifyModel(definition.name, raw: raw);
}

/// Builds capability metadata for an [OmlxModelDefinition].
genkit.ModelInfo modelInfoFor(OmlxModelDefinition definition) {
  final provided = definition.modelInfo;
  return genkit.ModelInfo(
    versions: provided?.versions,
    label: provided?.label ?? 'oMLX - ${definition.name}',
    configSchema: provided?.configSchema,
    supports: <String, dynamic>{
      'multiturn': true,
      'systemRole': true,
      'tools': definition.supportsTools,
      'toolChoice': definition.supportsTools,
      'media': definition.supportsMedia,
      'constrained': definition.supportsConstrainedOutput ? 'all' : 'none',
      ...?provided?.supports,
    },
    stage: provided?.stage,
  );
}

/// Builds capability metadata for a text-to-speech [OmlxModelDefinition].
genkit.ModelInfo speechModelInfoFor(OmlxModelDefinition definition) {
  final provided = definition.modelInfo;
  return genkit.ModelInfo(
    versions: provided?.versions,
    label: provided?.label ?? 'oMLX Speech - ${definition.name}',
    configSchema: provided?.configSchema,
    supports: <String, dynamic>{
      'media': false,
      'output': ['media'],
      'multiturn': false,
      'systemRole': false,
      'tools': false,
      ...?provided?.supports,
    },
    stage: provided?.stage,
  );
}

/// Builds capability metadata for a speech-to-text [OmlxModelDefinition].
genkit.ModelInfo transcriptionModelInfoFor(OmlxModelDefinition definition) {
  final provided = definition.modelInfo;
  return genkit.ModelInfo(
    versions: provided?.versions,
    label: provided?.label ?? 'oMLX Transcription - ${definition.name}',
    configSchema: provided?.configSchema,
    supports: <String, dynamic>{
      'media': true,
      'output': ['text', 'json'],
      'multiturn': false,
      'systemRole': false,
      'tools': false,
      ...?provided?.supports,
    },
    stage: provided?.stage,
  );
}

/// Builds action metadata for an [OmlxModelDefinition].
Map<String, dynamic> actionMetadataForModel(
  OmlxModelDefinition definition, {
  genkit.ModelInfo? modelInfo,
}) {
  final info = modelInfo ?? modelInfoFor(definition);
  return <String, dynamic>{
    'label': info.label ?? 'oMLX - ${definition.name}',
    'description': definition.name,
    'model': <String, dynamic>{
      ...info.toJson(),
      'customOptions': omlxGenerationConfigSchema().jsonSchema(),
    },
  };
}

/// Builds action metadata for a text-to-speech [OmlxModelDefinition].
Map<String, dynamic> actionMetadataForSpeechModel(
  OmlxModelDefinition definition, {
  genkit.ModelInfo? modelInfo,
}) {
  final info = modelInfo ?? speechModelInfoFor(definition);
  return <String, dynamic>{
    'label': info.label ?? 'oMLX Speech - ${definition.name}',
    'description': definition.name,
    'model': <String, dynamic>{
      ...info.toJson(),
      'customOptions': omlxSpeechConfigSchema().jsonSchema(),
    },
  };
}

/// Builds action metadata for a speech-to-text [OmlxModelDefinition].
Map<String, dynamic> actionMetadataForTranscriptionModel(
  OmlxModelDefinition definition, {
  genkit.ModelInfo? modelInfo,
}) {
  final info = modelInfo ?? transcriptionModelInfoFor(definition);
  return <String, dynamic>{
    'label': info.label ?? 'oMLX Transcription - ${definition.name}',
    'description': definition.name,
    'model': <String, dynamic>{
      ...info.toJson(),
      'customOptions': omlxTranscriptionConfigSchema().jsonSchema(),
    },
  };
}

/// Builds action metadata for an [OmlxEmbedderDefinition].
Map<String, dynamic> actionMetadataForEmbedder(
  OmlxEmbedderDefinition definition,
) {
  final info = definition.modelInfo;
  return <String, dynamic>{
    'label': info?.label ?? 'oMLX Embedding - ${definition.name}',
    'description': definition.name,
    'model': <String, dynamic>{
      'label': info?.label ?? 'oMLX Embedding - ${definition.name}',
      if (definition.dimensions != null) 'dimensions': definition.dimensions,
      'supports': <String, dynamic>{
        'input': ['text'],
        ...?info?.supports,
      },
      ...info?.toJson() ?? const <String, dynamic>{},
      'customOptions': omlxEmbedConfigSchema().jsonSchema(),
    },
  };
}

/// Builds Genkit [genkit.ActionMetadata] for an [OmlxModelDefinition].
genkit.ActionMetadata modelActionMetadata(
  OmlxModelDefinition definition, {
  String namespace = defaultOmlxNamespace,
  genkit.ModelInfo? modelInfo,
}) {
  final info = modelInfo ?? modelInfoFor(definition);
  return genkit.modelMetadata(
    actionNameFor(definition.name, namespace: namespace),
    info: info,
    customOptions: omlxGenerationConfigSchema(),
  );
}

/// Builds Genkit [genkit.ActionMetadata] for a text-to-speech [OmlxModelDefinition].
genkit.ActionMetadata speechModelActionMetadata(
  OmlxModelDefinition definition, {
  String namespace = defaultOmlxNamespace,
  genkit.ModelInfo? modelInfo,
}) {
  final info = modelInfo ?? speechModelInfoFor(definition);
  return genkit.modelMetadata(
    actionNameFor(definition.name, namespace: namespace),
    info: info,
    customOptions: omlxSpeechConfigSchema(),
  );
}

/// Builds Genkit [genkit.ActionMetadata] for a speech-to-text [OmlxModelDefinition].
genkit.ActionMetadata transcriptionModelActionMetadata(
  OmlxModelDefinition definition, {
  String namespace = defaultOmlxNamespace,
  genkit.ModelInfo? modelInfo,
}) {
  final info = modelInfo ?? transcriptionModelInfoFor(definition);
  return genkit.modelMetadata(
    actionNameFor(definition.name, namespace: namespace),
    info: info,
    customOptions: omlxTranscriptionConfigSchema(),
  );
}

/// Builds Genkit [genkit.ActionMetadata] for an [OmlxEmbedderDefinition].
genkit.ActionMetadata embedderActionMetadata(
  OmlxEmbedderDefinition definition, {
  String namespace = defaultOmlxNamespace,
}) {
  final base = genkit.embedderMetadata(
    actionNameFor(definition.name, namespace: namespace),
    customOptions: omlxEmbedConfigSchema(),
  );

  final metadata = <String, dynamic>{
    ...base.metadata,
    'model': <String, dynamic>{
      if (base.metadata['model'] is Map)
        ...(base.metadata['model'] as Map).cast<String, dynamic>(),
      'label':
          definition.modelInfo?.label ?? 'oMLX Embedding - ${definition.name}',
      if (definition.dimensions != null) 'dimensions': definition.dimensions,
      'supports': <String, dynamic>{
        'input': ['text'],
        ...?definition.modelInfo?.supports,
      },
      'customOptions': omlxEmbedConfigSchema().jsonSchema(),
    },
  };

  return genkit.ActionMetadata(
    name: base.name,
    description: base.description ?? definition.name,
    actionType: genkit.ActionType.embedder,
    inputSchema: genkit.EmbedRequest.$schema,
    outputSchema: genkit.EmbedResponse.$schema,
    metadata: metadata,
  );
}

/// Builds action metadata for an [OmlxRerankerDefinition].
Map<String, dynamic> actionMetadataForReranker(
  OmlxRerankerDefinition definition,
) {
  final info = definition.modelInfo;
  final label = info?.label ?? 'oMLX Reranker - ${definition.name}';
  return <String, dynamic>{
    'label': label,
    'description': definition.name,
    'reranker': <String, dynamic>{
      'label': label,
      'supports': <String, dynamic>{
        'input': ['text'],
        ...?info?.supports,
      },
      ...info?.toJson() ?? const <String, dynamic>{},
      'customOptions': omlxRerankConfigSchema().jsonSchema(),
    },
  };
}

/// Builds Genkit [genkit.ActionMetadata] for an [OmlxRerankerDefinition].
genkit.ActionMetadata rerankerActionMetadata(
  OmlxRerankerDefinition definition, {
  String namespace = defaultOmlxNamespace,
}) {
  return genkit.ActionMetadata(
    name: actionNameFor(definition.name, namespace: namespace),
    description: definition.name,
    actionType: omlxRerankerActionType,
    inputSchema: OmlxRerankRequest.$schema,
    outputSchema: OmlxRerankResponse.$schema,
    metadata: actionMetadataForReranker(definition),
  );
}

/// Builds raw provider metadata returned in `ModelResponse.raw`.
Map<String, dynamic> rawResponseMetadata(
  OmlxModelDefinition definition, {
  String namespace = defaultOmlxNamespace,
  bool structured = false,
  Map<String, dynamic>? rawResponse,
  Map<String, dynamic>? extra,
}) {
  return <String, dynamic>{
    'provider': namespace,
    'model': definition.model,
    if (structured) 'structured': true,
    ...?rawResponse,
    ...?extra,
  };
}
