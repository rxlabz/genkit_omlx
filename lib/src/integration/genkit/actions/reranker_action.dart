import 'package:domlx/domlx.dart' as omlx;
import 'package:genkit/plugin.dart' as genkit;
import 'package:schemantic/schemantic.dart';

import '../../../api/rerank_config.dart';
import '../../../api/reranker_definition.dart';
import '../../../core/client/omlx_client_manager.dart';
import '../action_support.dart';
import '../error_mapping.dart';

/// Genkit [genkit.Action] for an oMLX semantic document reranker (`/v1/rerank`).
base class OmlxReranker<CustomOptions>
    extends genkit.Action<OmlxRerankRequest, OmlxRerankResponse, void, void>
    implements OmlxRerankerRef<CustomOptions> {
  /// Creates an oMLX reranker action.
  OmlxReranker({
    required super.name,
    required genkit.ActionFn<OmlxRerankRequest, OmlxRerankResponse, void, void>
    fn,
    super.metadata,
    this.config,
    this.customOptions,
  }) : super(
         actionType: omlxRerankerActionType,
         inputSchema: OmlxRerankRequest.$schema,
         outputSchema: OmlxRerankResponse.$schema,
         fn: (input, ctx) {
           if (input == null) {
             throw genkit.GenkitException(
               'Reranker "$name" requires a non-null input.',
               status: genkit.StatusCode.invalidArgument,
             );
           }
           return fn(input, ctx);
         },
       );

  @override
  final CustomOptions? config;

  @override
  final SchemanticType<CustomOptions>? customOptions;
}

/// Builds a Genkit [OmlxReranker] action for an [OmlxRerankerDefinition].
OmlxReranker<OmlxRerankConfig> buildRerankerAction({
  required OmlxRerankerDefinition definition,
  required OmlxClientManager clientManager,
  String namespace = defaultOmlxNamespace,
}) {
  final actionName = actionNameFor(definition.name, namespace: namespace);

  return OmlxReranker<OmlxRerankConfig>(
    name: actionName,
    customOptions: omlxRerankConfigSchema(),
    metadata: actionMetadataForReranker(definition),
    fn: (request, _) async {
      final config = parseOmlxRerankConfig(request.options);
      validateOmlxRerankConfig(config);

      final queryText = _extractDocumentText(request.query);
      if (queryText.isEmpty) {
        throw genkit.GenkitException(
          'Reranker query document contains no text content.',
          status: genkit.StatusCode.invalidArgument,
        );
      }

      if (request.documents.isEmpty) {
        return OmlxRerankResponse(documents: const []);
      }

      final docTexts = <String>[];
      for (var i = 0; i < request.documents.length; i++) {
        final text = _extractDocumentText(request.documents[i]);
        if (text.isEmpty) {
          throw genkit.GenkitException(
            'Reranker document at index $i contains no text content.',
            status: genkit.StatusCode.invalidArgument,
          );
        }
        docTexts.add(text);
      }

      final wireModel = config.version ?? definition.model;

      try {
        final response = await clientManager.client.rerank.create(
          omlx.RerankRequest(
            model: wireModel,
            query: queryText,
            documents: docTexts,
            topN: config.topN,
            returnDocuments: config.returnDocuments ?? true,
          ),
        );

        final ranked = <OmlxRankedDocument>[];
        for (final item in response.results) {
          if (item.index < 0 || item.index >= request.documents.length) {
            throw genkit.GenkitException(
              'oMLX reranker returned out-of-range document index ${item.index} '
              'for ${request.documents.length} input documents.',
              status: genkit.StatusCode.internal,
            );
          }

          final sourceDoc = request.documents[item.index];
          final enrichedDoc = genkit.DocumentData(
            content: sourceDoc.content,
            metadata: <String, dynamic>{
              ...?sourceDoc.metadata,
              'score': item.relevanceScore,
              'index': item.index,
            },
          );

          ranked.add(
            OmlxRankedDocument(
              index: item.index,
              score: item.relevanceScore,
              document: enrichedDoc,
            ),
          );
        }

        return OmlxRerankResponse(documents: ranked);
      } catch (e, stackTrace) {
        Error.throwWithStackTrace(toGenkitException(e, stackTrace), stackTrace);
      }
    },
  );
}

String _extractDocumentText(genkit.DocumentData doc) {
  return doc.content
      .where((p) => p.isText)
      .map((p) => p.text!)
      .join('\n')
      .trim();
}
