// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rerank_config.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

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
base class OmlxRerankConfig {
  /// Creates a [OmlxRerankConfig] from a JSON map.
  factory OmlxRerankConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OmlxRerankConfig._(this._json);

  OmlxRerankConfig({String? version, int? topN, bool? returnDocuments}) {
    _json = {
      'version': ?version,
      'top_n': ?topN,
      'return_documents': ?returnDocuments,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [OmlxRerankConfig].
  static const SchemanticType<OmlxRerankConfig> $schema =
      _OmlxRerankConfigTypeFactory();

  /// Optional model identifier override (e.g. `'BAAI/bge-reranker-v2-m3'`).
  String? get version {
    return _json['version'] as String?;
  }

  /// Optional model identifier override (e.g. `'BAAI/bge-reranker-v2-m3'`).
  set version(String? value) {
    if (value == null) {
      _json.remove('version');
    } else {
      _json['version'] = value;
    }
  }

  /// Maximum number of top-scoring documents to return.
  int? get topN {
    return (_json['top_n'] as num?)?.toInt();
  }

  /// Maximum number of top-scoring documents to return.
  set topN(int? value) {
    if (value == null) {
      _json.remove('top_n');
    } else {
      _json['top_n'] = value;
    }
  }

  /// Whether the server should include document text in the raw response.
  bool? get returnDocuments {
    return _json['return_documents'] as bool?;
  }

  /// Whether the server should include document text in the raw response.
  set returnDocuments(bool? value) {
    if (value == null) {
      _json.remove('return_documents');
    } else {
      _json['return_documents'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [OmlxRerankConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _OmlxRerankConfigTypeFactory
    extends SchemanticType<OmlxRerankConfig> {
  const _OmlxRerankConfigTypeFactory();

  @override
  OmlxRerankConfig parse(Object? json) {
    return OmlxRerankConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OmlxRerankConfig',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Request-time options for oMLX document rerankers.',
      'properties': <String, Object?>{
        'version': <String, Object?>{'type': 'string'},
        'top_n': <String, Object?>{
          'type': 'integer',
          'description': 'Maximum number of top-scoring documents to return.',
          'minimum': 1,
        },
        'return_documents': <String, Object?>{
          'type': 'boolean',
          'description': 'Whether the server should include document text in the response.',
        },
      },
    },
    dependencies: [],
  );
}

/// Input payload for an oMLX reranker [Action].
base class OmlxRerankRequest {
  /// Creates a [OmlxRerankRequest] from a JSON map.
  factory OmlxRerankRequest.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OmlxRerankRequest._(this._json);

  OmlxRerankRequest({
    required DocumentData query,
    required List<DocumentData> documents,
    Map<String, dynamic>? options,
  }) {
    _json = {
      'query': query.toJson(),
      'documents': documents.map((e) => e.toJson()).toList(),
      'options': ?options,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [OmlxRerankRequest].
  static const SchemanticType<OmlxRerankRequest> $schema =
      _OmlxRerankRequestTypeFactory();

  /// The search query document to rank candidates against.
  DocumentData get query {
    return DocumentData.fromJson(_json['query'] as Map<String, dynamic>);
  }

  /// The search query document to rank candidates against.
  set query(DocumentData value) {
    _json['query'] = value.toJson();
  }

  /// Candidate documents to score and rank.
  List<DocumentData> get documents {
    return (_json['documents'] as List)
        .map((e) => DocumentData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Candidate documents to score and rank.
  set documents(List<DocumentData> value) {
    _json['documents'] = value.map((e) => e.toJson()).toList();
  }

  /// Optional reranker configuration (`top_n`, `return_documents`, `version`).
  Map<String, dynamic>? get options {
    return (_json['options'] as Map?)?.cast<String, dynamic>();
  }

  /// Optional reranker configuration (`top_n`, `return_documents`, `version`).
  set options(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('options');
    } else {
      _json['options'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [OmlxRerankRequest] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _OmlxRerankRequestTypeFactory
    extends SchemanticType<OmlxRerankRequest> {
  const _OmlxRerankRequestTypeFactory();

  @override
  OmlxRerankRequest parse(Object? json) {
    return OmlxRerankRequest._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OmlxRerankRequest',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Input request for an oMLX reranker action.',
      'properties': <String, Object?>{
        'query': <String, Object?>{r'$ref': r'#/$defs/DocumentData'},
        'documents': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{r'$ref': r'#/$defs/DocumentData'},
        },
        'options': <String, Object?>{
          'type': 'object',
          'additionalProperties': <String, Object?>{},
        },
      },
      'required': ['query', 'documents'],
    },
    dependencies: [DocumentData.$schema],
  );
}

/// A single document scored and ordered by an oMLX reranker.
base class OmlxRankedDocument {
  /// Creates a [OmlxRankedDocument] from a JSON map.
  factory OmlxRankedDocument.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OmlxRankedDocument._(this._json);

  OmlxRankedDocument({
    required int index,
    required double score,
    required DocumentData document,
  }) {
    _json = {'index': index, 'score': score, 'document': document.toJson()};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [OmlxRankedDocument].
  static const SchemanticType<OmlxRankedDocument> $schema =
      _OmlxRankedDocumentTypeFactory();

  /// Original 0-based index of this document in the input list.
  int get index {
    return (_json['index'] as num).toInt();
  }

  /// Original 0-based index of this document in the input list.
  set index(int value) {
    _json['index'] = value;
  }

  /// Relevance score computed by the cross-encoder / reranker model.
  double get score {
    return (_json['score'] as num).toDouble();
  }

  /// Relevance score computed by the cross-encoder / reranker model.
  set score(double value) {
    _json['score'] = value;
  }

  /// The ranked document (with `score` and `index` merged into its metadata).
  DocumentData get document {
    return DocumentData.fromJson(_json['document'] as Map<String, dynamic>);
  }

  /// The ranked document (with `score` and `index` merged into its metadata).
  set document(DocumentData value) {
    _json['document'] = value.toJson();
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [OmlxRankedDocument] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _OmlxRankedDocumentTypeFactory
    extends SchemanticType<OmlxRankedDocument> {
  const _OmlxRankedDocumentTypeFactory();

  @override
  OmlxRankedDocument parse(Object? json) {
    return OmlxRankedDocument._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OmlxRankedDocument',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'A document scored and ranked by an oMLX reranker.',
      'properties': <String, Object?>{
        'index': <String, Object?>{'type': 'integer'},
        'score': <String, Object?>{'type': 'number'},
        'document': <String, Object?>{r'$ref': r'#/$defs/DocumentData'},
      },
      'required': ['index', 'score', 'document'],
    },
    dependencies: [DocumentData.$schema],
  );
}

/// Output payload returned by an oMLX reranker [Action].
base class OmlxRerankResponse {
  /// Creates a [OmlxRerankResponse] from a JSON map.
  factory OmlxRerankResponse.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OmlxRerankResponse._(this._json);

  OmlxRerankResponse({required List<OmlxRankedDocument> documents}) {
    _json = {'documents': documents.map((e) => e.toJson()).toList()};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [OmlxRerankResponse].
  static const SchemanticType<OmlxRerankResponse> $schema =
      _OmlxRerankResponseTypeFactory();

  /// Documents ordered from most relevant to least relevant.
  List<OmlxRankedDocument> get documents {
    return (_json['documents'] as List)
        .map((e) => OmlxRankedDocument.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Documents ordered from most relevant to least relevant.
  set documents(List<OmlxRankedDocument> value) {
    _json['documents'] = value.map((e) => e.toJson()).toList();
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [OmlxRerankResponse] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _OmlxRerankResponseTypeFactory
    extends SchemanticType<OmlxRerankResponse> {
  const _OmlxRerankResponseTypeFactory();

  @override
  OmlxRerankResponse parse(Object? json) {
    return OmlxRerankResponse._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OmlxRerankResponse',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Output response from an oMLX reranker action.',
      'properties': <String, Object?>{
        'documents': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{r'$ref': r'#/$defs/OmlxRankedDocument'},
        },
      },
      'required': ['documents'],
    },
    dependencies: [OmlxRankedDocument.$schema],
  );
}
