import 'dart:convert';

import 'package:domlx/domlx.dart' as omlx;
import 'package:genkit/plugin.dart' as genkit;

import '../../../api/model_definition.dart';
import '../../../api/speech_config.dart';
import '../../../core/client/omlx_client_manager.dart';
import '../action_support.dart';
import '../error_mapping.dart';

/// Builds a Genkit [genkit.Model] action for an oMLX text-to-speech model.
///
/// Speech models synthesize the last non-system message's text into a single
/// audio [genkit.MediaPart] containing a base64 data URI.
genkit.Model<OmlxSpeechConfig> buildSpeechModelAction({
  required OmlxModelDefinition definition,
  required OmlxClientManager clientManager,
  String namespace = defaultOmlxNamespace,
}) {
  final modelInfo = speechModelInfoFor(definition);
  final actionName = actionNameFor(definition.name, namespace: namespace);

  return genkit.Model<OmlxSpeechConfig>(
    name: actionName,
    customOptions: omlxSpeechConfigSchema(),
    metadata: actionMetadataForSpeechModel(definition, modelInfo: modelInfo),
    fn: (request, _) async {
      final config = parseOmlxSpeechConfig(request.config);
      validateOmlxSpeechConfig(config);

      final input = _speechInputText(request);
      final wireModel = config.version ?? definition.model;
      final format = config.responseFormat ?? defaultOmlxSpeechFormat;
      final voice = config.voice ?? defaultOmlxSpeechVoice;

      final started = Stopwatch()..start();

      try {
        final bytes = await clientManager.client.audio.speech(
          omlx.AudioSpeechRequest(
            model: wireModel,
            input: input,
            voice: voice,
            responseFormat: format,
            speed: config.speed,
          ),
        );

        if (bytes.isEmpty) {
          throw genkit.GenkitException(
            'The oMLX speech endpoint returned no audio.',
            status: genkit.StatusCode.internal,
          );
        }

        final contentType =
            speechResponseFormatMediaTypes[format] ?? 'audio/mpeg';

        return genkit.ModelResponse(
          finishReason: genkit.FinishReason.stop,
          latencyMs: started.elapsedMilliseconds.toDouble(),
          message: genkit.Message(
            role: genkit.Role.model,
            content: [
              genkit.MediaPart(
                media: genkit.Media(
                  contentType: contentType,
                  url: 'data:$contentType;base64,${base64Encode(bytes)}',
                ),
              ),
            ],
          ),
          raw: rawResponseMetadata(
            definition,
            namespace: namespace,
            rawResponse: {
              'model': wireModel,
              'voice': voice,
              'response_format': format,
              if (config.speed != null) 'speed': config.speed,
            },
          ),
        );
      } catch (e, stackTrace) {
        Error.throwWithStackTrace(toGenkitException(e, stackTrace), stackTrace);
      }
    },
  );
}

String _speechInputText(genkit.ModelRequest request) {
  if (request.messages.isEmpty) {
    throw genkit.GenkitException(
      'Speech models require a prompt, but no messages were provided.',
      status: genkit.StatusCode.invalidArgument,
    );
  }

  final spoken = request.messages.lastWhere(
    (message) => message.role != genkit.Role.system,
    orElse: () => throw genkit.GenkitException(
      'Speech models require a prompt, but only a system message was provided.',
      status: genkit.StatusCode.invalidArgument,
    ),
  );

  final text = spoken.text;
  if (text.trim().isEmpty) {
    throw genkit.GenkitException(
      'Speech models require non-empty prompt text.',
      status: genkit.StatusCode.invalidArgument,
    );
  }

  return text;
}
