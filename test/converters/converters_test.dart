import 'package:domlx/domlx.dart' as omlx;
import 'package:genkit/plugin.dart' as genkit;
import 'package:genkit_omlx/src/integration/genkit/converters/genkit_to_omlx.dart';
import 'package:genkit_omlx/src/integration/genkit/converters/omlx_to_genkit.dart';
import 'package:test/test.dart';

void main() {
  group('genkit_to_omlx converters', () {
    test('converts system message', () {
      final messages = [
        genkit.Message(
          role: genkit.Role.system,
          content: [genkit.TextPart(text: 'System instruction')],
        ),
      ];

      final converted = toOmlxMessages(messages);
      expect(converted.length, equals(1));
      expect(converted[0].role, equals('system'));
      expect(converted[0].textContent, equals('System instruction'));
    });

    test('converts user text message', () {
      final messages = [
        genkit.Message(
          role: genkit.Role.user,
          content: [genkit.TextPart(text: 'Hello oMLX')],
        ),
      ];

      final converted = toOmlxMessages(messages);
      expect(converted.length, equals(1));
      expect(converted[0].role, equals('user'));
      expect(converted[0].textContent, equals('Hello oMLX'));
    });

    test('converts assistant message with text and reasoning', () {
      final messages = [
        genkit.Message(
          role: genkit.Role.model,
          content: [
            genkit.ReasoningPart(reasoning: 'Thinking process...'),
            genkit.TextPart(text: 'Final answer'),
          ],
        ),
      ];

      final converted = toOmlxMessages(messages);
      expect(converted.length, equals(1));
      expect(converted[0].role, equals('assistant'));
      expect(converted[0].textContent, equals('Final answer'));
      expect(converted[0].reasoningContent, equals('Thinking process...'));
    });

    test('converts assistant message with tool request', () {
      final messages = [
        genkit.Message(
          role: genkit.Role.model,
          content: [
            genkit.ToolRequestPart(
              toolRequest: genkit.ToolRequest(
                ref: 'call_abc123',
                name: 'get_weather',
                input: {'location': 'Tokyo'},
              ),
            ),
          ],
        ),
      ];

      final converted = toOmlxMessages(messages);
      expect(converted.length, equals(1));
      expect(converted[0].role, equals('assistant'));
      expect(converted[0].toolCalls?.length, equals(1));
      expect(converted[0].toolCalls![0].id, equals('call_abc123'));
      expect(converted[0].toolCalls![0].function.name, equals('get_weather'));
      expect(
        converted[0].toolCalls![0].function.arguments,
        contains('"location":"Tokyo"'),
      );
    });

    test('converts tool response message', () {
      final messages = [
        genkit.Message(
          role: genkit.Role.tool,
          content: [
            genkit.ToolResponsePart(
              toolResponse: genkit.ToolResponse(
                ref: 'call_abc123',
                name: 'get_weather',
                output: {'temp': 22, 'condition': 'Sunny'},
              ),
            ),
          ],
        ),
      ];

      final converted = toOmlxMessages(messages);
      expect(converted.length, equals(1));
      expect(converted[0].role, equals('tool'));
      expect(converted[0].toolCallId, equals('call_abc123'));
      expect(converted[0].textContent, contains('"temp":22'));
    });

    test('converts tool definitions', () {
      final tools = [
        genkit.ToolDefinition(
          name: 'calculator',
          description: 'Evaluates expressions',
          inputSchema: {
            'type': 'object',
            'properties': {
              'expression': {'type': 'string'},
            },
            'required': ['expression'],
          },
        ),
      ];

      final omlxTools = toOmlxTools(tools);
      expect(omlxTools, isNotNull);
      expect(omlxTools!.length, equals(1));
      expect(omlxTools[0].function.name, equals('calculator'));
      expect(
        omlxTools[0].function.description,
        equals('Evaluates expressions'),
      );
      expect(
        omlxTools[0].function.parameters?['required'],
        equals(['expression']),
      );
    });

    test('converts response format for json schema and object', () {
      final schemaConfig = genkit.OutputConfig(
        schema: {
          'type': 'object',
          'properties': {
            'result': {'type': 'string'},
          },
        },
      );

      final rfSchema = toOmlxResponseFormat(schemaConfig);
      expect(rfSchema, isNotNull);
      expect(rfSchema!.type, equals('json_schema'));
      expect(rfSchema.jsonSchema?['name'], equals('response'));
      expect(rfSchema.jsonSchema?['strict'], isFalse);

      final jsonConfig = genkit.OutputConfig(format: 'json');
      final rfJson = toOmlxResponseFormat(jsonConfig);
      expect(rfJson, isNotNull);
      expect(rfJson!.type, equals('json_object'));
    });

    test('flattens tool input schema with defs and refs', () {
      final tools = [
        genkit.ToolDefinition(
          name: 'create_user',
          description: 'Creates a user with address',
          inputSchema: {
            'type': 'object',
            'properties': {
              'address': {r'$ref': r'#/$defs/Address'},
            },
            r'$defs': {
              'Address': {
                'type': 'object',
                'properties': {
                  'street': {'type': 'string'},
                },
              },
            },
          },
        ),
      ];

      final omlxTools = toOmlxTools(tools);
      expect(omlxTools, isNotNull);
      expect(omlxTools!.length, equals(1));
      final params = omlxTools[0].function.parameters;
      expect(params, isNotNull);
      expect(params!['type'], equals('object'));
      // Check that the schema was processed and valid
      expect(params['properties'], isNotNull);
    });

    test('respects jsonMode and strict in response format', () {
      final schemaConfig = genkit.OutputConfig(
        schema: {
          'type': 'object',
          'properties': {
            'count': {'type': 'integer'},
          },
        },
      );

      // jsonMode forces json_object even if schema is provided
      final rfJsonMode = toOmlxResponseFormat(schemaConfig, jsonMode: true);
      expect(rfJsonMode, isNotNull);
      expect(rfJsonMode!.type, equals('json_object'));

      // strict = true sets strict: true on json_schema
      final rfStrict = toOmlxResponseFormat(schemaConfig, strict: true);
      expect(rfStrict, isNotNull);
      expect(rfStrict!.type, equals('json_schema'));
      expect(rfStrict.jsonSchema?['strict'], isTrue);
    });
  });

  group('omlx_to_genkit converters', () {
    test('converts ChatCompletion with text, reasoning, and usage', () {
      final completion = omlx.ChatCompletion(
        id: 'cmpl_123',
        created: 123456789,
        model: 'qwen',
        choices: [
          omlx.ChatChoice(
            index: 0,
            message: omlx.ChatMessage.assistant(
              'Here is your answer.',
              reasoningContent: 'First I analyzed X, then Y.',
            ),
            finishReason: 'stop',
          ),
        ],
        usage: const omlx.Usage(
          promptTokens: 15,
          completionTokens: 30,
          totalTokens: 45,
          cachedTokens: 10,
        ),
      );

      final response = toGenkitModelResponse(
        completion,
        latencyMs: 125.0,
        raw: {'provider': 'omlx'},
      );

      expect(response.message?.role, equals(genkit.Role.model));
      expect(response.finishReason, equals(genkit.FinishReason.stop));
      expect(response.latencyMs, equals(125.0));

      final reasoningParts = response.message!.content
          .where((p) => p.isReasoning)
          .map((p) => p.reasoning)
          .toList();
      expect(reasoningParts, equals(['First I analyzed X, then Y.']));

      final textParts = response.message!.content
          .where((p) => p.isText)
          .map((p) => p.text)
          .toList();
      expect(textParts, equals(['Here is your answer.']));

      expect(response.usage?.inputTokens, equals(15.0));
      expect(response.usage?.outputTokens, equals(30.0));
      expect(response.usage?.totalTokens, equals(45.0));
      expect(response.usage?.cachedContentTokens, equals(10.0));
    });

    test('converts streaming chunk with delta text and reasoning', () {
      final chunk = omlx.ChatCompletionChunk(
        id: 'chunk_1',
        created: 123456,
        model: 'qwen',
        choices: [
          const omlx.ChatChunkChoice(
            index: 0,
            delta: omlx.ChatDelta(
              role: 'assistant',
              content: 'hello',
              reasoningContent: 'think',
            ),
          ),
        ],
      );

      final genkitChunk = toGenkitChunk(chunk);
      expect(genkitChunk, isNotNull);
      expect(genkitChunk!.role, equals(genkit.Role.model));
      expect(genkitChunk.content.length, equals(2));
      expect(genkitChunk.content[0].reasoning, equals('think'));
      expect(genkitChunk.content[1].text, equals('hello'));
    });

    test('maps finish reasons correctly', () {
      expect(mapFinishReason('stop'), equals(genkit.FinishReason.stop));
      expect(mapFinishReason('length'), equals(genkit.FinishReason.length));
      expect(mapFinishReason('tool_calls'), equals(genkit.FinishReason.stop));
      expect(
        mapFinishReason('content_filter'),
        equals(genkit.FinishReason.blocked),
      );
      expect(mapFinishReason(null), equals(genkit.FinishReason.stop));
      expect(mapFinishReason('other'), equals(genkit.FinishReason.unknown));
    });
  });
}
