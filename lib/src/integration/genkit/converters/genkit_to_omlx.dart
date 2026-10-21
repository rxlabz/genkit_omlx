import 'dart:convert';
import 'dart:io';

import 'package:domlx/domlx.dart' as omlx;
import 'package:genkit/plugin.dart' as genkit;
import 'package:schemantic/schemantic.dart';

/// Converts Genkit messages to oMLX [omlx.ChatMessage] objects.
List<omlx.ChatMessage> toOmlxMessages(List<genkit.Message> messages) {
  final converted = <omlx.ChatMessage>[];

  for (final message in messages) {
    if (message.role == genkit.Role.tool) {
      final toolResponses = message.content
          .where((part) => part.isToolResponse && part.toolResponse != null)
          .map((part) => part.toolResponse!)
          .toList(growable: false);

      if (toolResponses.isEmpty) {
        throw genkit.GenkitException(
          'Tool messages must contain at least one tool response part.',
          status: genkit.StatusCode.invalidArgument,
        );
      }

      for (final resp in toolResponses) {
        converted.add(
          omlx.ChatMessage.tool(
            toolCallId: resp.ref ?? '',
            content: _normalizeToolOutput(resp.output),
          ),
        );
      }
      continue;
    }

    if (message.role == genkit.Role.system) {
      final text = message.content
          .where((part) => part.isText)
          .map((part) => part.text ?? '')
          .join('\n');
      converted.add(omlx.ChatMessage.system(text));
      continue;
    }

    if (message.role == genkit.Role.model) {
      final textBuffer = StringBuffer();
      final reasoningBuffer = StringBuffer();
      final toolCalls = <omlx.ToolCall>[];

      for (final part in message.content) {
        if (part.isText) {
          textBuffer.write(part.text ?? '');
        } else if (part.isReasoning) {
          reasoningBuffer.write(part.reasoning ?? '');
        } else if (part.isToolRequest) {
          final tr = part.toolRequest;
          if (tr != null) {
            final input = tr.input;
            final argsString = input is String ? input : jsonEncode(input);
            toolCalls.add(
              omlx.ToolCall(
                id: tr.ref ?? 'call_${toolCalls.length}',
                function: omlx.FunctionCall(
                  name: tr.name,
                  arguments: argsString,
                ),
              ),
            );
          }
        }
      }

      final content = textBuffer.toString();
      final reasoning = reasoningBuffer.toString();

      converted.add(
        omlx.ChatMessage.assistant(
          content.isEmpty && toolCalls.isNotEmpty ? null : content,
          reasoningContent: reasoning.isEmpty ? null : reasoning,
          toolCalls: toolCalls.isEmpty ? null : toolCalls,
        ),
      );
      continue;
    }

    // Role.user or custom
    final hasMedia = message.content.any((part) => part.isMedia);
    if (!hasMedia) {
      final text = message.content
          .where((part) => part.isText)
          .map((part) => part.text ?? '')
          .join('\n');
      converted.add(omlx.ChatMessage.user(text));
    } else {
      final parts = <omlx.ContentPart>[];
      for (final part in message.content) {
        if (part.isText) {
          parts.add(omlx.ContentPart.text(part.text ?? ''));
        } else if (part.isMedia && part.media != null) {
          parts.add(_toOmlxImagePart(part.media!));
        }
      }
      converted.add(omlx.ChatMessage.user(parts));
    }
  }

  return converted;
}

/// Converts Genkit tool definitions to oMLX [omlx.Tool] objects.
List<omlx.Tool>? toOmlxTools(List<genkit.ToolDefinition>? tools) {
  if (tools == null || tools.isEmpty) {
    return null;
  }

  return tools
      .map((tool) {
        var parameters = _inlinedToolSchema(tool);

        if (parameters == null) {
          parameters = {'type': 'object', 'properties': <String, dynamic>{}};
        } else if (!parameters.containsKey('type')) {
          parameters = {'type': 'object', ...parameters};
        } else if (parameters['type'] != 'object') {
          throw genkit.GenkitException(
            'oMLX requires tool parameters to be an object schema; tool '
            '"${tool.name}" declares type "${parameters['type']}". '
            'Wrap the input in an object schema.',
            status: genkit.StatusCode.invalidArgument,
          );
        }

        return omlx.Tool.function(
          name: tool.name,
          description: tool.description,
          parameters: parameters,
        );
      })
      .toList(growable: false);
}

Map<String, dynamic>? _inlinedToolSchema(genkit.ToolDefinition tool) {
  final schema = tool.inputSchema;
  if (schema == null) return null;
  try {
    return schema.flatten().cast<String, dynamic>();
  } on FormatException {
    return _withRootDefPromoted(schema);
  }
}

Map<String, dynamic> _withRootDefPromoted(Map<String, dynamic> schema) {
  final ref = schema[r'$ref'];
  if (ref is! String) return schema;

  final defsKey = schema.containsKey(r'$defs') ? r'$defs' : 'definitions';
  final defs = schema[defsKey];
  if (defs is! Map) return schema;

  final root = defs[ref.split('/').last];
  if (root is! Map) return schema;

  final promoted = root.cast<String, dynamic>();
  if (promoted.containsKey(r'$ref') || promoted['type'] != 'object') {
    return schema;
  }

  return {...promoted, defsKey: defs.cast<String, dynamic>()};
}

/// Resolves tool choice configuration for oMLX.
dynamic toOmlxToolChoice(genkit.ToolChoice? toolChoice, {required bool hasTools}) {
  if (!hasTools) {
    return null;
  }

  return switch (toolChoice?.value) {
    'none' => 'none',
    'required' => 'required',
    _ => 'auto',
  };
}

/// Maps Genkit output configuration to an oMLX [omlx.ResponseFormat].
omlx.ResponseFormat? toOmlxResponseFormat(
  genkit.OutputConfig? output, {
  bool? jsonMode,
  bool? strict,
}) {
  if (output != null) {
    final isJson = output.format == 'json' ||
        output.contentType == 'application/json' ||
        output.schema != null;

    if (isJson) {
      if (jsonMode == true) {
        return omlx.ResponseFormat.jsonObject;
      }
      if (output.schema != null) {
        Map<String, dynamic> flattenedSchema;
        try {
          flattenedSchema = output.schema!.flatten().cast<String, dynamic>();
        } catch (_) {
          flattenedSchema = output.schema!;
        }

        return omlx.ResponseFormat.jsonSchema(
          name: 'response',
          schema: flattenedSchema,
          strict: strict ?? false,
        );
      }
      return omlx.ResponseFormat.jsonObject;
    }

    if (output.format == 'text') {
      return omlx.ResponseFormat.text;
    }
  }

  if (jsonMode == true) {
    return omlx.ResponseFormat.jsonObject;
  }

  return null;
}

/// Checks whether structured generation is required by the output config.
bool shouldUseStructuredGeneration(genkit.OutputConfig? output) {
  if (output == null || output.constrained == false) {
    return false;
  }

  return output.schema != null ||
      output.format == 'json' ||
      output.contentType == 'application/json';
}

/// Extracts plain text from a Genkit [genkit.DocumentData] for embedding.
String documentToPlainText(genkit.DocumentData document) {
  final buffer = StringBuffer();

  for (final part in document.content) {
    if (part.isText) {
      buffer.write(part.text ?? '');
    } else if (part.isReasoning) {
      continue;
    } else {
      throw genkit.GenkitException(
        'oMLX embeddings only support text-only documents.',
        status: genkit.StatusCode.invalidArgument,
      );
    }
  }

  return buffer.toString();
}

omlx.ContentPart _toOmlxImagePart(genkit.Media media) {
  final url = media.url;
  final uri = Uri.tryParse(url);

  // If already data URI or remote HTTP URL, pass directly
  if (url.startsWith('data:') ||
      (uri != null && (uri.scheme == 'http' || uri.scheme == 'https'))) {
    return omlx.ContentPart.imageUrl(url);
  }

  // Handle local file URI or path
  try {
    final filePath = (uri != null && uri.scheme == 'file')
        ? uri.toFilePath()
        : url;
    final file = File(filePath);
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      final base64String = base64Encode(bytes);
      final mime =
          media.contentType ?? _inferMimeType(filePath) ?? 'image/jpeg';
      return omlx.ContentPart.imageUrl('data:$mime;base64,$base64String');
    }
  } catch (_) {
    // Fallback to passing the URL directly
  }

  return omlx.ContentPart.imageUrl(url);
}

String? _inferMimeType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return null;
}

String _normalizeToolOutput(Object? output) {
  if (output == null) return 'null';
  if (output is String) return output;
  try {
    return jsonEncode(output);
  } catch (_) {
    return output.toString();
  }
}
