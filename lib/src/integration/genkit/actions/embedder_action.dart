import 'package:domlx/domlx.dart' as omlx;
import 'package:genkit/plugin.dart' as genkit;

import '../../../api/embed_config.dart';
import '../../../api/embedder_definition.dart';
import '../../../core/client/omlx_client_manager.dart';
import '../action_support.dart';
import '../converters/genkit_to_omlx.dart';
import '../error_mapping.dart';

/// Maximum number of documents sent in a single `POST /v1/embeddings` call.
const int maxEmbeddingBatchSize = 512;

/// Builds a Genkit [genkit.Embedder] action for an [OmlxEmbedderDefinition].
genkit.Embedder<OmlxEmbedConfig> buildEmbedderAction({
  required OmlxEmbedderDefinition definition,
  required OmlxClientManager clientManager,
  String namespace = defaultOmlxNamespace,
}) {
  final actionName = actionNameFor(definition.name, namespace: namespace);

  return genkit.Embedder<OmlxEmbedConfig>(
    name: actionName,
    customOptions: omlxEmbedConfigSchema(),
    metadata: actionMetadataForEmbedder(definition),
    fn: (request, _) async {
      if (request.input.isEmpty) {
        return genkit.EmbedResponse(embeddings: const []);
      }

      final config = parseOmlxEmbedConfig(request.options);
      final wireModel = config.version ?? definition.model;
      final texts = <String>[];
      for (var i = 0; i < request.input.length; i++) {
        texts.add(documentToPlainText(request.input[i], index: i));
      }

      try {
        final allEmbeddings = <genkit.Embedding>[];
        var documentOffset = 0;

        for (var i = 0; i < texts.length; i += maxEmbeddingBatchSize) {
          final batch = texts.sublist(
            i,
            (i + maxEmbeddingBatchSize).clamp(0, texts.length),
          );

          final response = await clientManager.client.embeddings.create(
            omlx.EmbeddingRequest.batch(
              model: wireModel,
              texts: batch,
              encodingFormat: config.encodingFormat,
              dimensions: config.dimensions ?? definition.dimensions,
              user: config.user,
            ),
          );

          if (response.data.length != batch.length) {
            throw genkit.GenkitException(
              'oMLX returned ${response.data.length} embeddings for ${batch.length} input documents.',
              status: genkit.StatusCode.internal,
            );
          }

          final sortedData = [...response.data]
            ..sort((a, b) => a.index.compareTo(b.index));

          for (var j = 0; j < sortedData.length; j++) {
            final item = sortedData[j];
            final docIdx = documentOffset + j;
            final metadata = docIdx < request.input.length
                ? request.input[docIdx].metadata
                : null;
            allEmbeddings.add(
              genkit.Embedding(
                embedding: item.embedding ?? const <double>[],
                metadata: metadata,
              ),
            );
          }

          documentOffset += batch.length;
        }

        return genkit.EmbedResponse(embeddings: allEmbeddings);
      } catch (e, stackTrace) {
        Error.throwWithStackTrace(toGenkitException(e, stackTrace), stackTrace);
      }
    },
  );
}
