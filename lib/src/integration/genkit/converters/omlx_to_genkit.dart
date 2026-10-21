import 'dart:convert';

import 'package:domlx/domlx.dart' as omlx;
import 'package:genkit/plugin.dart' as genkit;

/// Converts an oMLX [omlx.ChatCompletion] response into a Genkit [genkit.ModelResponse].
genkit.ModelResponse toGenkitModelResponse(
  omlx.ChatCompletion completion, {
  required double latencyMs,
  required Map<String, dynamic> raw,
}) {
  final choice = completion.choices.isNotEmpty
      ? completion.choices.first
      : null;
  final message = choice?.message;
  final parts = <genkit.Part>[];

  if (message != null) {
    if (message.reasoningContent != null &&
        message.reasoningContent!.isNotEmpty) {
      parts.add(genkit.ReasoningPart(reasoning: message.reasoningContent!));
    }

    if (message.textContent.isNotEmpty ||
        (message.toolCalls == null && parts.isEmpty)) {
      parts.add(genkit.TextPart(text: message.textContent));
    }

    if (message.toolCalls != null) {
      for (final toolCall in message.toolCalls!) {
        parts.add(toGenkitToolRequestPart(toolCall));
      }
    }
  }

  return genkit.ModelResponse(
    message: genkit.Message(
      role: genkit.Role.model,
      content: parts.isEmpty ? <genkit.Part>[genkit.TextPart(text: '')] : parts,
    ),
    finishReason: mapFinishReason(choice?.finishReason),
    usage: toGenkitUsage(completion.usage),
    latencyMs: latencyMs,
    raw: raw,
  );
}

/// Converts an oMLX [omlx.ChatCompletionChunk] into a Genkit [genkit.ModelResponseChunk].
genkit.ModelResponseChunk? toGenkitChunk(omlx.ChatCompletionChunk chunk) {
  if (chunk.choices.isEmpty) {
    return null;
  }

  final choice = chunk.choices.first;
  final delta = choice.delta;
  final parts = <genkit.Part>[];

  if (delta.reasoningContent != null && delta.reasoningContent!.isNotEmpty) {
    parts.add(genkit.ReasoningPart(reasoning: delta.reasoningContent!));
  }

  if (delta.content != null && delta.content!.isNotEmpty) {
    parts.add(genkit.TextPart(text: delta.content!));
  }

  if (delta.toolCalls != null) {
    for (final toolCall in delta.toolCalls!) {
      parts.add(toGenkitToolRequestPart(toolCall));
    }
  }

  if (parts.isEmpty) {
    return null;
  }

  return genkit.ModelResponseChunk(
    role: genkit.Role.model,
    index: choice.index,
    content: parts,
    aggregated: false,
  );
}

/// Converts an oMLX [omlx.ToolCall] to a Genkit [genkit.ToolRequestPart].
genkit.ToolRequestPart toGenkitToolRequestPart(omlx.ToolCall toolCall) {
  final function = toolCall.function;
  final rawArgs = function.arguments;

  return genkit.ToolRequestPart(
    toolRequest: genkit.ToolRequest(
      ref: toolCall.id?.isNotEmpty == true ? toolCall.id! : 'call_0',
      name: function.name,
      input: _decodeToolArguments(rawArgs),
    ),
    metadata: rawArgs.isEmpty
        ? null
        : <String, dynamic>{'rawArguments': rawArgs},
  );
}

/// Maps an oMLX finish reason string to a Genkit [genkit.FinishReason].
genkit.FinishReason mapFinishReason(String? reason) {
  return switch (reason) {
    'stop' => genkit.FinishReason.stop,
    'length' => genkit.FinishReason.length,
    'tool_calls' => genkit.FinishReason.stop,
    'content_filter' => genkit.FinishReason.blocked,
    null => genkit.FinishReason.stop,
    _ => genkit.FinishReason.unknown,
  };
}

/// Maps an oMLX [omlx.Usage] stats object to a Genkit [genkit.GenerationUsage].
genkit.GenerationUsage? toGenkitUsage(omlx.Usage? usage) {
  if (usage == null) {
    return null;
  }

  final custom = <String, dynamic>{
    if (usage.cachedTokens != null) 'cachedTokens': usage.cachedTokens,
    if (usage.prefillDuration != null) 'prefillDuration': usage.prefillDuration,
    if (usage.generationDuration != null)
      'generationDuration': usage.generationDuration,
    if (usage.promptTokensDetails != null)
      'promptTokensDetails': usage.promptTokensDetails,
  };

  return genkit.GenerationUsage(
    inputTokens: usage.promptTokens,
    outputTokens: usage.completionTokens,
    totalTokens: usage.totalTokens,
    cachedContentTokens: usage.cachedTokens,
    custom: custom.isEmpty ? null : custom,
  );
}

Map<String, dynamic> _decodeToolArguments(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const <String, dynamic>{};
  }

  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    return <String, dynamic>{'value': decoded};
  } catch (_) {
    return <String, dynamic>{'_raw': raw};
  }
}
