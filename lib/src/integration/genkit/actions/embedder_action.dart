import 'package:domlx/domlx.dart' as omlx;
import 'package:genkit/plugin.dart' as genkit;

import '../../../api/embed_config.dart';
import '../../../api/embedder_definition.dart';
import '../../../core/client/omlx_client_manager.dart';
import '../action_support.dart';
import '../converters/genkit_to_omlx.dart';

/// Builds a Genkit [genkit.Embedder] action for an [OmlxEmbedderDefinition].
genkit.Embedder<OmlxEmbedConfig> buildEmbedderAction({
  required OmlxEmbedderDefinition definition,
  required OmlxClientManager clientManager,
}) {
  final actionName = actionNameFor(definition.name);

  return genkit.Embedder<OmlxEmbedConfig>(
    name: actionName,
    customOptions: omlxEmbedConfigSchema(),
    metadata: actionMetadataForEmbedder(definition),
    fn: (request, _) async {
      final config = parseOmlxEmbedConfig(request.options);
      final texts = request.input
          .map(documentToPlainText)
          .toList(growable: false);

      final response = await clientManager.client.embeddings.create(
        omlx.EmbeddingRequest(
          model: definition.model,
          input: texts,
          encodingFormat: config.encodingFormat,
          dimensions: config.dimensions ?? definition.dimensions,
          user: config.user,
        ),
      );

      final embeddings = <genkit.Embedding>[];
      for (var i = 0; i < response.data.length; i++) {
        final item = response.data[i];
        final metadata = i < request.input.length
            ? request.input[i].metadata
            : null;
        embeddings.add(
          genkit.Embedding(
            embedding: item.embedding ?? const <double>[],
            metadata: metadata,
          ),
        );
      }

      return genkit.EmbedResponse(embeddings: embeddings);
    },
  );
}
