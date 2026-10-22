import 'dart:async';

import 'package:domlx/domlx.dart' as omlx;
import 'package:genkit/plugin.dart' as genkit;

import '../../../api/generation_config.dart';
import '../../../api/model_definition.dart';
import '../../../core/client/omlx_client_manager.dart';
import '../action_support.dart';
import '../converters/genkit_to_omlx.dart';
import '../converters/omlx_to_genkit.dart';
import '../error_mapping.dart';

typedef _ModelActionContext =
    genkit.ActionFnArg<genkit.ModelResponseChunk, genkit.ModelRequest, void>;

/// Builds a Genkit [genkit.Model] action for an [OmlxModelDefinition].
genkit.Model<OmlxGenerationConfig> buildModelAction({
  required OmlxModelDefinition definition,
  required OmlxClientManager clientManager,
  String namespace = defaultOmlxNamespace,
}) {
  final modelInfo = modelInfoFor(definition);
  final actionName = actionNameFor(definition.name, namespace: namespace);

  return genkit.Model<OmlxGenerationConfig>(
    name: actionName,
    customOptions: omlxGenerationConfigSchema(),
    metadata: actionMetadataForModel(definition, modelInfo: modelInfo),
    fn: (request, context) {
      return _runModel(
        definition: definition,
        clientManager: clientManager,
        request: request,
        context: context,
        namespace: namespace,
      );
    },
  );
}

Future<genkit.ModelResponse> _runModel({
  required OmlxModelDefinition definition,
  required OmlxClientManager clientManager,
  required genkit.ModelRequest request,
  required _ModelActionContext context,
  String namespace = defaultOmlxNamespace,
}) async {
  if (request.docs != null && request.docs!.isNotEmpty) {
    throw genkit.GenkitException(
      'oMLX model actions do not support `docs` yet.',
      status: genkit.StatusCode.invalidArgument,
    );
  }

  final hasTools = request.tools?.isNotEmpty ?? false;
  if (hasTools && !definition.supportsTools) {
    throw genkit.GenkitException(
      'Tool use is disabled for `${definition.name}`.',
      status: genkit.StatusCode.failedPrecondition,
    );
  }

  if (shouldUseStructuredGeneration(request.output) &&
      !definition.supportsConstrainedOutput) {
    throw genkit.GenkitException(
      'Constrained output is disabled for `${definition.name}`.',
      status: genkit.StatusCode.failedPrecondition,
    );
  }

  final config = parseOmlxGenerationConfig(request.config);
  final wireModel = config.version ?? definition.model;
  final messages = await toOmlxMessagesAsync(request.messages);
  final tools = toOmlxTools(request.tools);
  final toolChoice = toOmlxToolChoice(
    request.toolChoice,
    hasTools: tools != null && tools.isNotEmpty,
  );
  final responseFormat = toOmlxResponseFormat(
    request.output,
    jsonMode: config.jsonMode,
    strict: config.strictJsonSchema,
  );

  final chatRequest = omlx.ChatCompletionRequest(
    model: wireModel,
    messages: messages,
    temperature: config.temperature,
    topP: config.topP,
    topK: config.topK,
    repetitionPenalty: config.repetitionPenalty,
    maxTokens: config.maxTokens,
    stream: context.streamingRequested,
    tools: tools,
    toolChoice: toolChoice,
    responseFormat: responseFormat,
    stop: config.stop,
    user: config.user,
    extra: config.extra ?? const {},
  );

  final started = Stopwatch()..start();

  if (context.streamingRequested) {
    return _runStreamingModel(
      definition: definition,
      clientManager: clientManager,
      chatRequest: chatRequest,
      responseFormat: responseFormat,
      context: context,
      started: started,
      namespace: namespace,
    );
  }

  try {
    final completion = await clientManager.client.chat.create(chatRequest);
    return toGenkitModelResponse(
      completion,
      latencyMs: started.elapsedMilliseconds.toDouble(),
      raw: rawResponseMetadata(
        definition,
        namespace: namespace,
        structured: responseFormat != null,
        rawResponse: completion.toJson(),
      ),
    );
  } catch (e, stackTrace) {
    Error.throwWithStackTrace(toGenkitException(e, stackTrace), stackTrace);
  }
}

Future<genkit.ModelResponse> _runStreamingModel({
  required OmlxModelDefinition definition,
  required OmlxClientManager clientManager,
  required omlx.ChatCompletionRequest chatRequest,
  required omlx.ResponseFormat? responseFormat,
  required _ModelActionContext context,
  required Stopwatch started,
  String namespace = defaultOmlxNamespace,
}) async {
  final textBuffer = StringBuffer();
  final reasoningBuffer = StringBuffer();
  final toolCallsByIndex = <int, _ToolCallAccumulator>{};
  String? finishReason;
  omlx.Usage? usage;

  try {
    final stream = clientManager.client.chat.createStream(chatRequest);

    await for (final chunk in stream) {
      if (chunk.usage != null) {
        usage = chunk.usage;
      }

      if (chunk.choices.isNotEmpty) {
        final choice = chunk.choices.first;
        if (choice.finishReason != null) {
          finishReason = choice.finishReason;
        }

        final delta = choice.delta;
        if (delta.content != null && delta.content!.isNotEmpty) {
          textBuffer.write(delta.content);
        }
        if (delta.reasoningContent != null &&
            delta.reasoningContent!.isNotEmpty) {
          reasoningBuffer.write(delta.reasoningContent);
        }

        if (delta.toolCalls != null) {
          for (var i = 0; i < delta.toolCalls!.length; i++) {
            final tc = delta.toolCalls![i];
            final callIndex = tc.index ?? toolCallsByIndex.length;
            final acc = toolCallsByIndex.putIfAbsent(
              callIndex,
              () => _ToolCallAccumulator(
                id: tc.id?.isNotEmpty == true ? tc.id! : 'call_$callIndex',
                name: tc.function.name,
              ),
            );
            if (tc.id?.isNotEmpty == true) {
              acc.id = tc.id!;
            }
            if (tc.function.name.isNotEmpty) {
              acc.name = tc.function.name;
            }
            acc.argumentsBuffer.write(tc.function.arguments);
          }
        }
      }

      final genkitChunk = toGenkitChunk(chunk);
      if (genkitChunk != null) {
        context.sendChunk(genkitChunk);
      }
    }
  } catch (e, stackTrace) {
    Error.throwWithStackTrace(toGenkitException(e, stackTrace), stackTrace);
  }

  final parts = <genkit.Part>[];
  final reasoning = reasoningBuffer.toString();
  if (reasoning.isNotEmpty) {
    parts.add(genkit.ReasoningPart(reasoning: reasoning));
  }

  final text = textBuffer.toString();
  if (text.isNotEmpty || (toolCallsByIndex.isEmpty && parts.isEmpty)) {
    parts.add(genkit.TextPart(text: text));
  }

  for (final acc in toolCallsByIndex.values) {
    parts.add(
      toGenkitToolRequestPart(
        omlx.ToolCall(
          id: acc.id,
          function: omlx.FunctionCall(
            name: acc.name,
            arguments: acc.argumentsBuffer.toString(),
          ),
        ),
      ),
    );
  }

  return genkit.ModelResponse(
    message: genkit.Message(role: genkit.Role.model, content: parts),
    finishReason: mapFinishReason(finishReason),
    usage: toGenkitUsage(usage),
    latencyMs: started.elapsedMilliseconds.toDouble(),
    raw: rawResponseMetadata(
      definition,
      namespace: namespace,
      structured: responseFormat != null,
      rawResponse: {
        'finish_reason': ?finishReason,
        'usage': ?usage?.toJson(),
      },
    ),
  );
}

class _ToolCallAccumulator {
  _ToolCallAccumulator({required this.id, required this.name});

  String id;
  String name;
  final StringBuffer argumentsBuffer = StringBuffer();
}
