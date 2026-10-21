import 'dart:async';

import 'package:domlx/domlx.dart' as omlx_sdk;
import 'package:genkit/plugin.dart';
import 'package:logging/logging.dart';

import '../../api/embedder_definition.dart';
import '../../api/model_definition.dart';
import '../../api/rerank_config.dart';
import '../../api/reranker_definition.dart';
import '../../core/client/omlx_client_manager.dart';
import 'action_support.dart';
import 'actions/embedder_action.dart';
import 'actions/model_action.dart';
import 'actions/reranker_action.dart';
import 'actions/speech_action.dart';
import 'actions/transcription_action.dart';
import 'error_mapping.dart';

final _logger = Logger('genkit_omlx');

/// Genkit plugin connecting local models served via oMLX.
class OmlxPlugin extends GenkitPlugin {
  /// Creates an oMLX Genkit plugin.
  OmlxPlugin({
    this.name = defaultOmlxNamespace,
    required this.clientManager,
    List<OmlxModelDefinition>? models,
    List<OmlxEmbedderDefinition>? embedders,
    List<OmlxRerankerDefinition>? rerankers,
  }) : _models = List<OmlxModelDefinition>.unmodifiable(models ?? const []),
       _embedders = List<OmlxEmbedderDefinition>.unmodifiable(
         embedders ?? const [],
       ),
       _rerankers = List<OmlxRerankerDefinition>.unmodifiable(
         rerankers ?? const [],
       ) {
    final modelNames = <String>{};
    for (final m in _models) {
      if (!modelNames.add(m.name)) {
        throw ArgumentError.value(
          m.name,
          'models',
          'Duplicate oMLX model name: ${m.name}',
        );
      }
    }

    final embedderNames = <String>{};
    for (final e in _embedders) {
      if (!embedderNames.add(e.name)) {
        throw ArgumentError.value(
          e.name,
          'embedders',
          'Duplicate oMLX embedder name: ${e.name}',
        );
      }
    }

    final rerankerNames = <String>{};
    for (final r in _rerankers) {
      if (!rerankerNames.add(r.name)) {
        throw ArgumentError.value(
          r.name,
          'rerankers',
          'Duplicate oMLX reranker name: ${r.name}',
        );
      }
    }
  }

  @override
  final String name;

  /// The underlying client manager.
  final OmlxClientManager clientManager;
  final List<OmlxModelDefinition> _models;
  final List<OmlxEmbedderDefinition> _embedders;
  final List<OmlxRerankerDefinition> _rerankers;

  final Map<String, Action> _resolvedActions = {};
  List<Action>? _initializedActions;

  /// Disposes the plugin and closes any open HTTP connections.
  Future<void> dispose() async {
    clientManager.close();
  }

  /// Resolves a registered Genkit alias (or `<namespace>/<name>`) to the
  /// underlying oMLX model identifier.
  ///
  /// If [nameOrId] does not match a statically declared model, embedder, or
  /// reranker alias, returns [nameOrId] with any leading namespace stripped.
  String resolveWireModelId(String nameOrId) {
    final normalized = _stripNamespacePrefix(nameOrId);
    for (final m in _models) {
      if (m.name == normalized || m.model == normalized) return m.model;
    }
    for (final e in _embedders) {
      if (e.name == normalized || e.model == normalized) return e.model;
    }
    for (final r in _rerankers) {
      if (r.name == normalized || r.model == normalized) return r.model;
    }
    return normalized;
  }

  /// Queries the health and engine pool status of the oMLX server (`GET /health`).
  Future<omlx_sdk.HealthResponse> health() async {
    try {
      return await clientManager.client.health();
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(toGenkitException(e, stackTrace), stackTrace);
    }
  }

  /// Queries detailed engine status and Apple Silicon unified memory state for
  /// models on the oMLX server (`GET /v1/models/status`).
  Future<List<omlx_sdk.ModelStatus>> modelsStatus() async {
    try {
      return await clientManager.client.models.status();
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(toGenkitException(e, stackTrace), stackTrace);
    }
  }

  /// Queries the status of a specific model by its Genkit alias or oMLX model ID
  /// (`GET /v1/models/status`).
  ///
  /// Returns `null` if the server does not report an entry for [nameOrId].
  Future<omlx_sdk.ModelStatus?> modelStatus(String nameOrId) async {
    final normalized = _stripNamespacePrefix(nameOrId);
    final wireId = resolveWireModelId(nameOrId);
    final statuses = await modelsStatus();
    for (final status in statuses) {
      if (status.modelId == wireId || status.modelId == normalized) {
        return status;
      }
    }
    return null;
  }

  /// Manually unloads/evicts a model from Apple Silicon unified memory
  /// (`POST /v1/models/{model_id}/unload`).
  ///
  /// Accepts either a registered Genkit alias (e.g. `'Qwen9'`) or a raw oMLX
  /// model ID (e.g. `'mlx-community/Qwen3.5-9B-MLX-4bit'`).
  Future<omlx_sdk.UnloadModelResponse> unloadModel(String nameOrId) async {
    final wireId = resolveWireModelId(nameOrId);
    try {
      return await clientManager.client.models.unload(wireId);
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(toGenkitException(e, stackTrace), stackTrace);
    }
  }

  /// Reranks candidate [documents] or [texts] against [query] using an oMLX
  /// reranker (`POST /v1/rerank`).
  ///
  /// - [reranker]: Either an [OmlxRerankerRef] (`omlx.reranker('...')`) or a
  ///   `String` reranker name / model ID.
  /// - [query]: Either a `String` query or a [DocumentData].
  /// - Provide exactly one of [documents] (`List<DocumentData>`) or [texts]
  ///   (`List<String>`).
  Future<List<OmlxRankedDocument>> rerank({
    required Object reranker,
    required Object query,
    List<DocumentData>? documents,
    List<String>? texts,
    OmlxRerankConfig? options,
  }) async {
    final String rerankerName;
    OmlxRerankConfig? defaultConfig;
    if (reranker is OmlxRerankerRef) {
      rerankerName = reranker.name;
      if (reranker.config is OmlxRerankConfig) {
        defaultConfig = reranker.config as OmlxRerankConfig;
      }
    } else if (reranker is String) {
      rerankerName = reranker;
    } else {
      throw ArgumentError.value(
        reranker,
        'reranker',
        'Expected OmlxRerankerRef or String model name.',
      );
    }

    final action =
        resolve(omlxRerankerActionType, rerankerName) as OmlxReranker?;
    if (action == null) {
      throw GenkitException(
        'Reranker $rerankerName not found',
        status: StatusCode.notFound,
      );
    }

    final req = _buildRerankRequest(
      query: query,
      documents: documents,
      texts: texts,
      options: options ?? defaultConfig,
    );
    final response = await action(req);
    return response.documents;
  }

  @override
  Future<List<Action>> init() async {
    if (_initializedActions != null) {
      return _initializedActions!;
    }

    final actions = <Action>[];

    for (final def in _models) {
      final action = _buildModelForDefinition(def);
      actions.add(action);
      _resolvedActions[_cacheKey(ActionType.model, def.name)] = action;
    }

    for (final def in _embedders) {
      final action = buildEmbedderAction(
        definition: def,
        clientManager: clientManager,
        namespace: name,
      );
      actions.add(action);
      _resolvedActions[_cacheKey(ActionType.embedder, def.name)] = action;
    }

    for (final def in _rerankers) {
      final action = buildRerankerAction(
        definition: def,
        clientManager: clientManager,
        namespace: name,
      );
      actions.add(action);
      _resolvedActions[_cacheKey(omlxRerankerActionType, def.name)] = action;
    }

    _initializedActions = List<Action>.unmodifiable(actions);
    return _initializedActions!;
  }

  @override
  Action? resolve(ActionType actionType, String name) {
    final normalizedName = _stripNamespacePrefix(name);
    final key = _cacheKey(actionType, normalizedName);

    final cached = _resolvedActions[key];
    if (cached != null) {
      return cached;
    }

    if (actionType == ActionType.model) {
      // Find matching definition or dynamically resolve
      final definition = _models.cast<OmlxModelDefinition?>().firstWhere(
        (m) => m?.name == normalizedName,
        orElse: () => OmlxModelDefinition(name: normalizedName),
      )!;

      final action = _buildModelForDefinition(definition);
      _resolvedActions[key] = action;
      return action;
    }

    if (actionType == ActionType.embedder) {
      final definition = _embedders.cast<OmlxEmbedderDefinition?>().firstWhere(
        (e) => e?.name == normalizedName,
        orElse: () => OmlxEmbedderDefinition(name: normalizedName),
      )!;

      final action = buildEmbedderAction(
        definition: definition,
        clientManager: clientManager,
        namespace: this.name,
      );
      _resolvedActions[key] = action;
      return action;
    }

    if (actionType == omlxRerankerActionType) {
      final definition = _rerankers.cast<OmlxRerankerDefinition?>().firstWhere(
        (r) => r?.name == normalizedName,
        orElse: () => OmlxRerankerDefinition(name: normalizedName),
      )!;

      final action = buildRerankerAction(
        definition: definition,
        clientManager: clientManager,
        namespace: this.name,
      );
      _resolvedActions[key] = action;
      return action;
    }

    return null;
  }

  @override
  Future<List<ActionMetadata>> list() async {
    final metadataList = <ActionMetadata>[];
    final declaredIds = <String>{};

    for (final def in _models) {
      declaredIds.add(def.name);
      declaredIds.add(def.model);
      metadataList.add(_metadataForModelDefinition(def));
    }

    for (final def in _embedders) {
      declaredIds.add(def.name);
      declaredIds.add(def.model);
      metadataList.add(embedderActionMetadata(def, namespace: name));
    }

    for (final def in _rerankers) {
      declaredIds.add(def.name);
      declaredIds.add(def.model);
      metadataList.add(rerankerActionMetadata(def, namespace: name));
    }

    // Try to dynamically discover models currently known to oMLX server
    try {
      final serverModels = await clientManager.client.models.list();
      for (final m in serverModels.data) {
        if (declaredIds.contains(m.id)) {
          continue;
        }
        final kind = classifyModel(m.id, raw: m.raw);
        if (kind == OmlxModelKind.embedding) {
          declaredIds.add(m.id);
          final def = OmlxEmbedderDefinition(name: m.id);
          metadataList.add(embedderActionMetadata(def, namespace: name));
        } else if (kind == OmlxModelKind.rerank) {
          declaredIds.add(m.id);
          final def = OmlxRerankerDefinition(name: m.id);
          metadataList.add(rerankerActionMetadata(def, namespace: name));
        } else if (kind == OmlxModelKind.speech ||
            kind == OmlxModelKind.transcription ||
            kind == OmlxModelKind.chat) {
          declaredIds.add(m.id);
          final def = OmlxModelDefinition(name: m.id);
          metadataList.add(_metadataForModelDefinition(def, raw: m.raw));
        }
      }
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to list models from $name; falling back to statically declared actions: $e',
        e,
        stackTrace,
      );
    }

    return metadataList;
  }

  String _stripNamespacePrefix(String value) {
    if (value.startsWith('$name/')) {
      return value.substring(name.length + 1);
    }
    if (value.startsWith('$defaultOmlxNamespace/')) {
      return value.substring(defaultOmlxNamespace.length + 1);
    }
    return value;
  }

  String _cacheKey(ActionType actionType, String normalizedName) =>
      '${actionType.value}:$normalizedName';

  Model _buildModelForDefinition(OmlxModelDefinition definition) {
    return switch (resolveModelKind(definition)) {
      OmlxModelKind.speech => buildSpeechModelAction(
        definition: definition,
        clientManager: clientManager,
        namespace: name,
      ),
      OmlxModelKind.transcription => buildTranscriptionModelAction(
        definition: definition,
        clientManager: clientManager,
        namespace: name,
      ),
      _ => buildModelAction(
        definition: definition,
        clientManager: clientManager,
        namespace: name,
      ),
    };
  }

  ActionMetadata _metadataForModelDefinition(
    OmlxModelDefinition definition, {
    Map<String, dynamic>? raw,
  }) {
    return switch (resolveModelKind(definition, raw: raw)) {
      OmlxModelKind.speech => speechModelActionMetadata(
        definition,
        namespace: name,
      ),
      OmlxModelKind.transcription => transcriptionModelActionMetadata(
        definition,
        namespace: name,
      ),
      _ => modelActionMetadata(definition, namespace: name),
    };
  }
}

/// Extension on [GenkitAI] adding first-class `ai.rerank(...)` support for
/// oMLX reranker actions.
extension OmlxGenkitRerankExtension on GenkitAI {
  /// Reranks candidate [documents] or [texts] against [query] using an oMLX
  /// [reranker] (`POST /v1/rerank`).
  ///
  /// - [query]: Either a `String` query or a [DocumentData].
  /// - Provide exactly one of [documents] (`List<DocumentData>`) or [texts]
  ///   (`List<String>`).
  Future<List<OmlxRankedDocument>> rerank<CustomOptions>({
    required OmlxRerankerRef<CustomOptions> reranker,
    required Object query,
    List<DocumentData>? documents,
    List<String>? texts,
    CustomOptions? options,
  }) async {
    final action = await registry.lookupAction(
      omlxRerankerActionType,
      reranker.name,
    );
    if (action == null) {
      throw GenkitException(
        'Reranker ${reranker.name} not found',
        status: StatusCode.notFound,
      );
    }

    final req = _buildRerankRequest(
      query: query,
      documents: documents,
      texts: texts,
      options: options ?? reranker.config,
    );

    final response = await action(req) as OmlxRerankResponse;
    return response.documents;
  }
}

OmlxRerankRequest _buildRerankRequest({
  required Object query,
  List<DocumentData>? documents,
  List<String>? texts,
  Object? options,
}) {
  if ((documents == null) == (texts == null)) {
    throw ArgumentError(
      'Provide exactly one of documents or texts to rerank.',
    );
  }

  final DocumentData queryDoc;
  if (query is DocumentData) {
    queryDoc = query;
  } else if (query is String) {
    queryDoc = DocumentData(content: [TextPart(text: query)]);
  } else {
    throw ArgumentError.value(
      query,
      'query',
      'Expected String or DocumentData.',
    );
  }

  final resolvedDocs =
      documents ??
      texts!
          .map((t) => DocumentData(content: [TextPart(text: t)]))
          .toList(growable: false);

  final Map<String, dynamic>? resolvedOptions;
  if (options == null) {
    resolvedOptions = null;
  } else if (options is Map<String, dynamic>) {
    resolvedOptions = options;
  } else if (options is Map) {
    resolvedOptions = options.cast<String, dynamic>();
  } else {
    resolvedOptions = (options as dynamic).toJson() as Map<String, dynamic>?;
  }

  return OmlxRerankRequest(
    query: queryDoc,
    documents: resolvedDocs,
    options: resolvedOptions,
  );
}
