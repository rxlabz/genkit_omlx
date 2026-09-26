import 'dart:async';

import 'package:genkit/plugin.dart';

import '../../api/embedder_definition.dart';
import '../../api/model_definition.dart';
import '../../core/client/omlx_client_manager.dart';
import 'action_support.dart';
import 'actions/embedder_action.dart';
import 'actions/model_action.dart';

/// Genkit plugin connecting local models served via oMLX.
class OmlxPlugin extends GenkitPlugin {
  /// Creates an oMLX Genkit plugin.
  OmlxPlugin({
    required OmlxClientManager clientManager,
    List<OmlxModelDefinition>? models,
    List<OmlxEmbedderDefinition>? embedders,
  }) : _clientManager = clientManager,
       _models = List<OmlxModelDefinition>.unmodifiable(models ?? const []),
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

  final OmlxClientManager _clientManager;
  final List<OmlxModelDefinition> _models;
  final List<OmlxEmbedderDefinition> _embedders;

  final Map<String, Action> _resolvedActions = {};
  List<Action>? _initializedActions;

  @override
  String get name => omlxPluginName;

  /// The underlying client manager.
  OmlxClientManager get clientManager => _clientManager;

  /// Disposes the plugin and closes any open HTTP connections.
  Future<void> dispose() async {
    _clientManager.close();
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
        clientManager: _clientManager,
      );
      actions.add(action);
      _resolvedActions[actionNameFor(def.name)] = action;
      _resolvedActions[def.name] = action;
    }

    for (final def in _embedders) {
      final action = buildEmbedderAction(
        definition: def,
        clientManager: _clientManager,
      );
      actions.add(action);
      _resolvedActions[actionNameFor(def.name)] = action;
      _resolvedActions[def.name] = action;
    }

    _initializedActions = List<Action>.unmodifiable(actions);
    return _initializedActions!;
  }

  @override
  Action? resolve(ActionType actionType, String name) {
    // Strip optional 'omlx/' prefix if present
    final normalizedName = name.startsWith('$omlxPluginName/')
        ? name.substring(omlxPluginName.length + 1)
        : name;

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
        clientManager: _clientManager,
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
        clientManager: _clientManager,
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
    final knownModelNames = <String>{};

    for (final def in _models) {
      knownModelNames.add(def.name);
      metadataList.add(
        ActionMetadata(
          name: actionNameFor(def.name),
          description: def.name,
          actionType: ActionType.model,
          metadata: actionMetadataForModel(def),
        ),
      );
    }

    for (final def in _embedders) {
      metadataList.add(
        ActionMetadata(
          name: actionNameFor(def.name),
          description: def.name,
          actionType: ActionType.embedder,
          metadata: actionMetadataForEmbedder(def),
        ),
      );
    }

    // Try to dynamically discover models currently known to oMLX server
    try {
      final serverModels = await _clientManager.client.models.list();
      for (final m in serverModels.data) {
        if (!knownModelNames.contains(m.id)) {
          final def = OmlxModelDefinition(name: m.id);
          metadataList.add(
            ActionMetadata(
              name: actionNameFor(def.name),
              description: def.name,
              actionType: ActionType.model,
              metadata: actionMetadataForModel(def),
            ),
          );
        }
      }
    } catch (_) {
      // If server is currently unreachable or offline, return statically known actions
    }

    return metadataList;
  }
}
