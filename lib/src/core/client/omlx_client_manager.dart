import 'package:domlx/domlx.dart';
import 'package:http/http.dart' as http;

/// Manages the lifecycle and connection parameters for an [OmlxClient].
class OmlxClientManager {
  /// Creates a client manager.
  OmlxClientManager({
    this.baseUrl = 'http://localhost:8000',
    this.apiKey,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 120),
    this.defaultHeaders = const {},
  }) : _client = OmlxClient(
         baseUrl: baseUrl,
         apiKey: apiKey,
         client: httpClient,
         timeout: timeout,
         defaultHeaders: defaultHeaders,
       );

  /// Server base URL.
  final String baseUrl;

  /// Optional Bearer API key.
  final String? apiKey;

  /// Request timeout.
  final Duration timeout;

  /// Default headers sent on every request.
  final Map<String, String> defaultHeaders;

  final OmlxClient _client;

  /// The underlying [OmlxClient] instance.
  OmlxClient get client => _client;

  /// Closes the client and associated resources.
  void close() {
    _client.close();
  }
}
