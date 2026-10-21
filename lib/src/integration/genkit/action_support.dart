import 'package:genkit/plugin.dart' as genkit;

import '../../api/embed_config.dart';
import '../../api/embedder_definition.dart';
import '../../api/generation_config.dart';
import '../../api/model_definition.dart';

/// Name of the oMLX Genkit plugin.
const String omlxPluginName = 'omlx';

/// Formats a model or embedder name into an action name (e.g. `omlx/<name>`).
String actionNameFor(String name) => '$omlxPluginName/$name';

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

/// Builds raw provider metadata returned in `ModelResponse.raw`.
Map<String, dynamic> rawResponseMetadata(
  OmlxModelDefinition definition, {
  bool structured = false,
  Map<String, dynamic>? extra,
}) {
  return <String, dynamic>{
    'provider': omlxPluginName,
    'model': definition.model,
    if (structured) 'structured': true,
    ...?extra,
  };
}
