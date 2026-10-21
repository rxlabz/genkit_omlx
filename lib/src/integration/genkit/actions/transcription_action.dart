import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:domlx/domlx.dart' as omlx;
import 'package:genkit/plugin.dart' as genkit;

import '../../../api/model_definition.dart';
import '../../../api/transcription_config.dart';
import '../../../core/client/omlx_client_manager.dart';
import '../action_support.dart';
import '../error_mapping.dart';

/// Builds a Genkit [genkit.Model] action for an oMLX speech-to-text model.
///
/// Transcription models read an audio [genkit.MediaPart] from the request and
/// return the transcript as a single [genkit.TextPart].
genkit.Model<OmlxTranscriptionConfig> buildTranscriptionModelAction({
  required OmlxModelDefinition definition,
  required OmlxClientManager clientManager,
  String namespace = defaultOmlxNamespace,
}) {
  final modelInfo = transcriptionModelInfoFor(definition);
  final actionName = actionNameFor(definition.name, namespace: namespace);

  return genkit.Model<OmlxTranscriptionConfig>(
    name: actionName,
    customOptions: omlxTranscriptionConfigSchema(),
    metadata: actionMetadataForTranscriptionModel(
      definition,
      modelInfo: modelInfo,
    ),
    fn: (request, _) async {
      final config = parseOmlxTranscriptionConfig(request.config);
      validateOmlxTranscriptionConfig(config);

      if (request.output?.format == 'media') {
        throw genkit.GenkitException(
          "Transcription models return text; output format 'media' is not supported.",
          status: genkit.StatusCode.invalidArgument,
        );
      }

      final audio = _extractTranscriptionAudio(request);
      final wireModel = config.version ?? definition.model;
      final format = config.responseFormat ?? defaultOmlxTranscriptionFormat;
      final promptHint = config.prompt ?? _extractPromptHint(request);
      final started = Stopwatch()..start();

      try {
        omlx.AudioTranscriptionResponse response;
        try {
          response = await clientManager.client.audio.transcribe(
            omlx.AudioTranscriptionRequest(
              fileBytes: audio.bytes,
              filename: audio.filename,
              model: wireModel,
              language: config.language,
              prompt: promptHint,
              responseFormat: format,
              temperature: config.temperature,
            ),
          );
        } on omlx.OmlxParsingException catch (e) {
          // Non-JSON formats ('text', 'srt', 'vtt') return plain text bodies
          // which trigger OmlxParsingException during JSON decoding.
          if ((format == 'text' || format == 'srt' || format == 'vtt') &&
              e.rawData != null) {
            response = omlx.AudioTranscriptionResponse(text: e.rawData!);
          } else {
            rethrow;
          }
        }

        final wantsJson = request.output?.format == 'json';
        final textContent = (wantsJson && response.raw.isNotEmpty)
            ? jsonEncode(response.raw)
            : response.text;

        return genkit.ModelResponse(
          finishReason: genkit.FinishReason.stop,
          latencyMs: started.elapsedMilliseconds.toDouble(),
          message: genkit.Message(
            role: genkit.Role.model,
            content: [genkit.TextPart(text: textContent)],
          ),
          raw: rawResponseMetadata(
            definition,
            namespace: namespace,
            rawResponse: response.raw.isNotEmpty ? response.raw : null,
            extra: <String, dynamic>{
              'model': wireModel,
              'format': format,
              'mimeType': audio.mimeType,
              if (config.language != null) 'language': config.language,
            },
          ),
        );
      } catch (e, stackTrace) {
        Error.throwWithStackTrace(toGenkitException(e, stackTrace), stackTrace);
      }
    },
  );
}

({Uint8List bytes, String mimeType, String filename})
_extractTranscriptionAudio(genkit.ModelRequest request) {
  genkit.Media? media;
  for (final message in request.messages) {
    if (message.media != null) {
      media = message.media;
      break;
    }
  }

  if (media == null) {
    throw genkit.GenkitException(
      'Transcription models require an audio media part in the request.',
      status: genkit.StatusCode.invalidArgument,
    );
  }

  final url = media.url;
  final uri = Uri.tryParse(url);

  // 1. Handle data: URI (e.g. data:audio/wav;base64,...)
  if (uri?.data != null) {
    final data = uri!.data!;
    final mimeType = (media.contentType ?? data.mimeType)
        .split(';')
        .first
        .trim()
        .toLowerCase();

    if (!mimeType.startsWith('audio/')) {
      throw genkit.GenkitException(
        'Transcription models require an audio/* media type; got "$mimeType".',
        status: genkit.StatusCode.invalidArgument,
      );
    }

    final bytes = data.contentAsBytes();
    if (bytes.isEmpty) {
      throw genkit.GenkitException(
        'Audio media part is empty.',
        status: genkit.StatusCode.invalidArgument,
      );
    }

    return (
      bytes: bytes,
      mimeType: mimeType,
      filename: audioFilenameFor(mimeType),
    );
  }

  // 2. Handle local file path or file:// URI for local Apple Silicon workflows
  if (uri == null || uri.scheme.isEmpty || uri.scheme == 'file') {
    final filePath = (uri != null && uri.scheme == 'file')
        ? uri.toFilePath()
        : url;
    final file = File(filePath);
    if (file.existsSync()) {
      final mimeType =
          (media.contentType ?? inferAudioMimeType(filePath) ?? '')
              .split(';')
              .first
              .trim()
              .toLowerCase();

      if (!mimeType.startsWith('audio/')) {
        throw genkit.GenkitException(
          'Transcription models require an audio/* media type; got "${mimeType.isEmpty ? filePath : mimeType}".',
          status: genkit.StatusCode.invalidArgument,
        );
      }

      final bytes = file.readAsBytesSync();
      if (bytes.isEmpty) {
        throw genkit.GenkitException(
          'Audio file is empty: $filePath',
          status: genkit.StatusCode.invalidArgument,
        );
      }

      return (
        bytes: bytes,
        mimeType: mimeType,
        filename: audioFilenameFor(mimeType),
      );
    }
  }

  throw genkit.GenkitException(
    'Transcription models require audio as a base64 data URL or existing local file; '
    'got "${url.split(':').first}".',
    status: genkit.StatusCode.invalidArgument,
  );
}

String? _extractPromptHint(genkit.ModelRequest request) {
  for (final message in request.messages) {
    if (message.role == genkit.Role.system) continue;
    final text = message.text.trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return null;
}
