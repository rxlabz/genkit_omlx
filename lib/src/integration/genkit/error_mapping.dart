import 'dart:async';

import 'package:domlx/domlx.dart' as omlx;
import 'package:genkit/plugin.dart' as genkit;

/// Maps exceptions from oMLX and underlying transports onto canonical [genkit.GenkitException]s.
genkit.GenkitException toGenkitException(Object error, [StackTrace? stackTrace]) {
  if (error is genkit.GenkitException) {
    return error;
  }

  final st = stackTrace ?? StackTrace.current;

  if (error is omlx.OmlxApiException) {
    final status = switch (error.statusCode) {
      507 => genkit.StatusCode.resourceExhausted,
      409 => genkit.StatusCode.aborted,
      _ => genkit.StatusCode.fromHttpStatus(error.statusCode),
    };

    return genkit.GenkitException(
      'oMLX API error: ${error.message}',
      status: status,
      details: error.details?.toString() ?? error.message,
      cause: error,
      stackTrace: st,
    );
  }

  if (error is omlx.OmlxNetworkException) {
    final status = error.cause is TimeoutException
        ? genkit.StatusCode.deadlineExceeded
        : genkit.StatusCode.unavailable;

    return genkit.GenkitException(
      'oMLX network error: ${error.message}',
      status: status,
      details: error.cause?.toString(),
      cause: error,
      stackTrace: st,
    );
  }

  if (error is omlx.OmlxParsingException) {
    return genkit.GenkitException(
      'oMLX parsing error: ${error.message}',
      status: genkit.StatusCode.internal,
      details: error.rawData,
      cause: error,
      stackTrace: st,
    );
  }

  if (error is TimeoutException) {
    return genkit.GenkitException(
      'oMLX request timed out: $error',
      status: genkit.StatusCode.deadlineExceeded,
      cause: error,
      stackTrace: st,
    );
  }

  return genkit.GenkitException(
    'oMLX error: $error',
    status: genkit.StatusCode.internal,
    details: error.toString(),
    cause: error,
    stackTrace: st,
  );
}
