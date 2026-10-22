import 'dart:async';

import 'package:domlx/domlx.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_omlx/src/integration/genkit/error_mapping.dart';
import 'package:test/test.dart';

void main() {
  group('error_mapping', () {
    test('maps OmlxApiException 507 to resourceExhausted (Apple Silicon OOM)', () {
      final error = OmlxApiException(
        statusCode: 507,
        message: 'Insufficient memory on Apple Silicon Unified Memory',
      );
      final genkitEx = toGenkitException(error);
      expect(genkitEx.status, equals(StatusCode.resourceExhausted));
      expect(
        genkitEx.message,
        contains('Insufficient memory on Apple Silicon Unified Memory'),
      );
    });

    test('maps OmlxApiException with code insufficient_memory and HTTP 500 to resourceExhausted', () {
      final error = OmlxApiException(
        statusCode: 500,
        code: 'insufficient_memory',
        message: 'GPU out of memory mid-stream',
      );
      final genkitEx = toGenkitException(error);
      expect(genkitEx.status, equals(StatusCode.resourceExhausted));
      expect(genkitEx.message, contains('GPU out of memory mid-stream'));
    });

    test('maps OmlxApiException with code context_length_exceeded to invalidArgument', () {
      final error = OmlxApiException(
        statusCode: 500,
        code: 'context_length_exceeded',
        message: 'Context length exceeded',
      );
      final genkitEx = toGenkitException(error);
      expect(genkitEx.status, equals(StatusCode.invalidArgument));
      expect(genkitEx.message, contains('Context length exceeded'));
    });

    test('maps OmlxApiException with model_not_found, invalid_api_key, and rate_limit_exceeded codes', () {
      final notFound = OmlxApiException(
        statusCode: 500,
        code: 'model_not_found',
        message: 'Model not found mid-stream',
      );
      expect(toGenkitException(notFound).status, equals(StatusCode.notFound));

      final unauth = OmlxApiException(
        statusCode: 500,
        code: 'invalid_api_key',
        message: 'Invalid API key',
      );
      expect(toGenkitException(unauth).status, equals(StatusCode.unauthenticated));

      final rateLimited = OmlxApiException(
        statusCode: 500,
        code: 'rate_limit_exceeded',
        message: 'Rate limit exceeded',
      );
      expect(
        toGenkitException(rateLimited).status,
        equals(StatusCode.resourceExhausted),
      );
    });

    test('maps OmlxApiException 409 to aborted (Model reload/swap conflict)', () {
      final error = OmlxApiException(
        statusCode: 409,
        message: 'Model is currently reloading',
      );
      final genkitEx = toGenkitException(error);
      expect(genkitEx.status, equals(StatusCode.aborted));
      expect(genkitEx.message, contains('Model is currently reloading'));
    });

    test('maps standard HTTP error codes correctly', () {
      final codeMap = {
        400: StatusCode.invalidArgument,
        401: StatusCode.unauthenticated,
        403: StatusCode.permissionDenied,
        404: StatusCode.notFound,
        429: StatusCode.resourceExhausted,
        500: StatusCode.internal,
        503: StatusCode.unavailable,
        504: StatusCode.deadlineExceeded,
      };

      for (final entry in codeMap.entries) {
        final error = OmlxApiException(
          statusCode: entry.key,
          message: 'Error ${entry.key}',
        );
        final genkitEx = toGenkitException(error);
        expect(
          genkitEx.status,
          equals(entry.value),
          reason: 'HTTP ${entry.key} should map to ${entry.value}',
        );
      }
    });

    test('maps OmlxNetworkException with TimeoutException to deadlineExceeded', () {
      final error = OmlxNetworkException(
        'Request timed out',
        cause: TimeoutException('Timeout after 30s'),
      );
      final genkitEx = toGenkitException(error);
      expect(genkitEx.status, equals(StatusCode.deadlineExceeded));
      expect(genkitEx.message, contains('Request timed out'));
    });

    test('maps OmlxNetworkException without TimeoutException to unavailable', () {
      final error = const OmlxNetworkException('Connection refused');
      final genkitEx = toGenkitException(error);
      expect(genkitEx.status, equals(StatusCode.unavailable));
    });

    test('maps OmlxParsingException to internal', () {
      final error = const OmlxParsingException('Invalid JSON payload');
      final genkitEx = toGenkitException(error);
      expect(genkitEx.status, equals(StatusCode.internal));
    });

    test('passes existing GenkitException through unchanged', () {
      final original = GenkitException(
        'Resource exists',
        status: StatusCode.alreadyExists,
      );
      final result = toGenkitException(original);
      expect(identical(result, original), isTrue);
    });

    test('maps unknown exception to internal', () {
      final error = StateError('Something broken');
      final genkitEx = toGenkitException(error);
      expect(genkitEx.status, equals(StatusCode.internal));
      expect(genkitEx.message, contains('Something broken'));
    });
  });
}
