import 'package:genkit/plugin.dart';
import 'package:schemantic/schemantic.dart';

part 'rerank_config.g.dart';

/// Request-time options for oMLX document reranking (`POST /v1/rerank`).
///
/// ```dart
/// final ranked = await ai.rerank(
///   reranker: omlx.reranker('BAAI/bge-reranker-v2-m3'),
///   query: 'Unified memory architecture on Apple Silicon',
///   texts: [
///     'CPU and GPU share the same physical LPDDR5X memory pool.',
///     'Baking sourdough bread requires a Dutch oven.',
///   ],
///   options: OmlxRerankConfig(topN: 1),
/// );
/// ```
@Schema(description: 'Request-time options for oMLX document rerankers.')
abstract class $OmlxRerankConfig {
  /// Optional model identifier override (e.g. `'BAAI/bge-reranker-v2-m3'`).
  String? get version;

  /// Maximum number of top-scoring documents to return.
  @IntegerField(
    name: 'top_n',
    description: 'Maximum number of top-scoring documents to return.',
    minimum: 1,
  )
  int? get topN;

  /// Whether the server should include document text in the raw response.
  @Field(
    name: 'return_documents',
    description:
        'Whether the server should include document text in the response.',
  )
  bool? get returnDocuments;
}

/// Input payload for an oMLX reranker [Action].
@Schema(description: 'Input request for an oMLX reranker action.')
abstract class $OmlxRerankRequest {
  /// The search query document to rank candidates against.
  $DocumentData get query;

  /// Candidate documents to score and rank.
  List<$DocumentData> get documents;

  /// Optional reranker configuration (`top_n`, `return_documents`, `version`).
  Map<String, dynamic>? get options;
}

/// A single document scored and ordered by an oMLX reranker.
@Schema(description: 'A document scored and ranked by an oMLX reranker.')
abstract class $OmlxRankedDocument {
  /// Original 0-based index of this document in the input list.
  int get index;

  /// Relevance score computed by the cross-encoder / reranker model.
  double get score;

  /// The ranked document (with `score` and `index` merged into its metadata).
  $DocumentData get document;
}

/// Output payload returned by an oMLX reranker [Action].
@Schema(description: 'Output response from an oMLX reranker action.')
abstract class $OmlxRerankResponse {
  /// Documents ordered from most relevant to least relevant.
  List<$OmlxRankedDocument> get documents;
}

/// Returns the Schemantic type descriptor for [OmlxRerankConfig].
SchemanticType<OmlxRerankConfig> omlxRerankConfigSchema() =>
    const _NormalizedOmlxRerankConfigSchema();

/// Parses [OmlxRerankConfig] from an action options map.
OmlxRerankConfig parseOmlxRerankConfig(Map<String, dynamic>? config) {
  if (config == null) return OmlxRerankConfig();
  return OmlxRerankConfig.$schema.parse(normalizeOmlxRerankConfig(config));
}

/// Normalizes camelCase and snake_case keys for [OmlxRerankConfig].
Map<String, dynamic> normalizeOmlxRerankConfig(Map<String, dynamic> raw) {
  final normalized = <String, dynamic>{};

  if (raw['version'] != null) {
    normalized['version'] = raw['version'].toString();
  }

  final topN = raw['top_n'] ?? raw['topN'] ?? raw['topK'] ?? raw['top_k'];
  if (topN is num) {
    normalized['top_n'] = topN.toInt();
  }

  final returnDocs = raw['return_documents'] ?? raw['returnDocuments'];
  if (returnDocs is bool) {
    normalized['return_documents'] = returnDocs;
  }

  return normalized;
}

/// Validates [OmlxRerankConfig] before sending a request to oMLX.
void validateOmlxRerankConfig(OmlxRerankConfig config) {
  final topN = config.topN;
  if (topN != null && topN < 1) {
    throw GenkitException(
      'topN must be at least 1; got $topN.',
      status: StatusCode.invalidArgument,
    );
  }
}

final class _NormalizedOmlxRerankConfigSchema
    extends SchemanticType<OmlxRerankConfig> {
  const _NormalizedOmlxRerankConfigSchema();

  @override
  OmlxRerankConfig parse(Object? json) {
    if (json == null || json is! Map) return OmlxRerankConfig();
    return OmlxRerankConfig.$schema.parse(
      normalizeOmlxRerankConfig(json.cast<String, dynamic>()),
    );
  }

  @override
  JsonSchemaMetadata? get schemaMetadata =>
      OmlxRerankConfig.$schema.schemaMetadata;

  @override
  Map<String, Object?> jsonSchema({bool useRefs = false}) =>
      OmlxRerankConfig.$schema.jsonSchema(useRefs: useRefs);
}
