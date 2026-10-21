import 'dart:async';

import 'package:genkit/plugin.dart';
import 'package:logging/logging.dart';

import '../../api/embedder_definition.dart';
import '../../api/model_definition.dart';
import '../../core/client/omlx_client_manager.dart';
import 'action_support.dart';
import 'actions/embedder_action.dart';
import 'actions/model_action.dart';

final _logger = Logger('genkit_omlx');

/// Genkit plugin connecting local models served via oMLX.
class OmlxPlugin extends GenkitPlugin {
  /// Creates an oMLX Genkit plugin.
  OmlxPlugin({
    this.name = defaultOmlxNamespace,
    required this.clientManager,
    List<OmlxModelDefinition>? models,
    List<OmlxEmbedderDefinition>? embedders,
  }) : _models = List<OmlxModelDefinition>.unmodifiable(models ?? const []),
       _embedders = List<OmlxEmbedderDefinition>.unmodifiable(
         embedders ?? const [],
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
  }

  @override
  final String name;

  /// The underlying client manager.
  final OmlxClientManager clientManager;
  final List<OmlxModelDefinition> _models;
  final List<OmlxEmbedderDefinition> _embedders;

  final Map<String, Action> _resolvedActions = {};
  List<Action>? _initializedActions;

  /// Disposes the plugin and closes any open HTTP connections.
  Future<void> dispose() async {
    clientManager.close();
  }

  @override
  Future<List<Action>> init() async {
    if (_initializedActions != null) {
      return _initializedActions!;
    }

    final actions = <Action>[];

    for (final def in _models) {
      final action = buildModelAction(
        definition: def,
        clientManager: clientManager,
        namespace: name,
      );
      actions.add(action);
      _resolvedActions[actionNameFor(def.name, namespace: name)] = action;
      _resolvedActions[def.name] = action;
    }

    for (final def in _embedders) {
      final action = buildEmbedderAction(
        definition: def,
        clientManager: clientManager,
        namespace: name,
      );
      actions.add(action);
      _resolvedActions[actionNameFor(def.name, namespace: name)] = action;
      _resolvedActions[def.name] = action;
    }

    _initializedActions = List<Action>.unmodifiable(actions);
    return _initializedActions!;
  }

  @override
  Action? resolve(ActionType actionType, String name) {
    // Strip optional namespace prefix if present
    var normalizedName = name;
    if (name.startsWith('${this.name}/')) {
      normalizedName = name.substring(this.name.length + 1);
    } else if (name.startsWith('$defaultOmlxNamespace/')) {
      normalizedName = name.substring(defaultOmlxNamespace.length + 1);
    }

    final cached = _resolvedActions[name] ?? _resolvedActions[normalizedName];
    if (cached != null) {
      return cached;
    }

    if (actionType == ActionType.model) {
      // Find matching definition or dynamically resolve
      final definition = _models.cast<OmlxModelDefinition?>().firstWhere(
        (m) => m?.name == normalizedName,
        orElse: () => OmlxModelDefinition(name: normalizedName),
      )!;

      final action = buildModelAction(
        definition: definition,
        clientManager: clientManager,
        namespace: this.name,
      );
      _resolvedActions[name] = action;
      _resolvedActions[normalizedName] = action;
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
      _resolvedActions[name] = action;
      _resolvedActions[normalizedName] = action;
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
      metadataList.add(modelActionMetadata(def, namespace: name));
    }

    for (final def in _embedders) {
      declaredIds.add(def.name);
      declaredIds.add(def.model);
      metadataList.add(embedderActionMetadata(def, namespace: name));
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
        } else if (kind == OmlxModelKind.chat) {
          declaredIds.add(m.id);
          final def = OmlxModelDefinition(name: m.id);
          metadataList.add(modelActionMetadata(def, namespace: name));
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
}
