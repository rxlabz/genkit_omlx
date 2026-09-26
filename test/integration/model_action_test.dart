import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_omlx/genkit_omlx.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('ModelAction integration', () {
    test('executes non-streaming completion', () async {
      late String capturedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/chat/completions') {
          capturedBody = request.body;
          final responsePayload = {
            'id': 'chatcmpl-1',
            'object': 'chat.completion',
            'created': 123456789,
            'model': 'mlx-community/Qwen2.5-7B-Instruct-4bit',
            'choices': [
              {
                'index': 0,
                'message': {
                  'role': 'assistant',
                  'content': 'Apple Silicon is fast and power efficient.',
                },
                'finish_reason': 'stop',
              },
            ],
            'usage': {
              'prompt_tokens': 12,
              'completion_tokens': 8,
              'total_tokens': 20,
            },
          };
          return http.Response(
            jsonEncode(responsePayload),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final plugin = omlx(
        httpClient: mockClient,
        models: const [
          OmlxModelDefinition(
            name: 'qwen',
            model: 'mlx-community/Qwen2.5-7B-Instruct-4bit',
          ),
        ],
      );

      final ai = Genkit(plugins: [plugin]);
      final response = await ai.generate(
        model: omlx.model('qwen'),
        prompt: 'Why Apple Silicon?',
        config: const OmlxGenerationConfig(temperature: 0.7),
      );

      expect(
        response.text,
        equals('Apple Silicon is fast and power efficient.'),
      );
      expect(response.finishReason, equals(FinishReason.stop));
      expect(response.usage?.totalTokens, equals(20.0));

      final decoded = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(
        decoded['model'],
        equals('mlx-community/Qwen2.5-7B-Instruct-4bit'),
      );
      expect(decoded['temperature'], equals(0.7));
      expect(decoded['stream'], isFalse);
    });

    test('executes streaming completion', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/chat/completions') {
          final sseData = [
            'data: {"id":"c1","choices":[{"index":0,"delta":{"role":"assistant","content":"Hello"}}]}\n\n',
            'data: {"id":"c1","choices":[{"index":0,"delta":{"content":" world"}}]}\n\n',
            'data: {"id":"c1","choices":[{"index":0,"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":5,"completion_tokens":2,"total_tokens":7}}\n\n',
            'data: [DONE]\n\n',
          ].join();

          return http.Response(
            sseData,
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }
        return http.Response('Not found', 404);
      });

      final plugin = omlx(
        httpClient: mockClient,
        models: const [OmlxModelDefinition(name: 'qwen')],
      );

      final ai = Genkit(plugins: [plugin]);
      final stream = ai.generateStream(
        model: omlx.model('qwen'),
        prompt: 'Say hello',
      );

      final chunks = <String>[];
      await for (final chunk in stream) {
        chunks.add(chunk.text);
      }

      expect(chunks, equals(['Hello', ' world']));
      final finalResponse = await stream.onResult;
      expect(finalResponse.text, equals('Hello world'));
      expect(finalResponse.finishReason, equals(FinishReason.stop));
      expect(finalResponse.usage?.totalTokens, equals(7.0));
    });

    test('extracts reasoning content from thinking models', () async {
      final mockClient = MockClient((request) async {
        final responsePayload = {
          'id': 'chatcmpl-r1',
          'object': 'chat.completion',
          'created': 123456789,
          'model': 'deepseek-r1-distill-qwen-7b',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'reasoning_content':
                    'Let square root of 9801 be x. 100^2 = 10000, 99^2 = 9801.',
                'content': 'The square root of 9801 is 99.',
              },
              'finish_reason': 'stop',
            },
          ],
          'usage': {
            'prompt_tokens': 10,
            'completion_tokens': 25,
            'total_tokens': 35,
          },
        };
        return http.Response(
          jsonEncode(responsePayload),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final plugin = omlx(
        httpClient: mockClient,
        models: const [OmlxModelDefinition(name: 'deepseek-r1')],
      );

      final ai = Genkit(plugins: [plugin]);
      final response = await ai.generate(
        model: omlx.model('deepseek-r1'),
        prompt: 'What is sqrt(9801)?',
      );

      expect(response.text, equals('The square root of 9801 is 99.'));
      final reasoning = response.message?.content
          .where((p) => p.isReasoning)
          .map((p) => p.reasoning)
          .firstOrNull;
      expect(reasoning, contains('100^2 = 10000, 99^2 = 9801'));
    });

    test('handles tool calls returned by assistant', () async {
      final mockClient = MockClient((request) async {
        final responsePayload = {
          'id': 'chatcmpl-tool',
          'object': 'chat.completion',
          'created': 123456789,
          'model': 'qwen',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': null,
                'tool_calls': [
                  {
                    'id': 'call_weather_1',
                    'type': 'function',
                    'function': {
                      'name': 'get_weather',
                      'arguments': '{"location":"Cupertino, CA"}',
                    },
                  },
                ],
              },
              'finish_reason': 'tool_calls',
            },
          ],
          'usage': {
            'prompt_tokens': 10,
            'completion_tokens': 5,
            'total_tokens': 15,
          },
        };
        return http.Response(
          jsonEncode(responsePayload),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final plugin = omlx(
        httpClient: mockClient,
        models: const [OmlxModelDefinition(name: 'qwen')],
      );

      final weatherTool = Tool<Map<String, dynamic>, String>(
        name: 'get_weather',
        description: 'Get weather',
        fn: (input, ctx) async => ToolResult.response('Sunny, 21C'),
      );

      final ai = Genkit(plugins: [plugin]);
      final response = await ai.generate(
        model: omlx.model('qwen'),
        prompt: 'Weather in Cupertino?',
        tools: [weatherTool],
        returnToolRequests: true,
      );

      expect(response.finishReason, equals(FinishReason.stop));
      final toolRequests = response.toolRequests;
      expect(toolRequests.length, equals(1));
      expect(toolRequests[0].name, equals('get_weather'));
      expect(toolRequests[0].ref, equals('call_weather_1'));
      expect(toolRequests[0].input, equals({'location': 'Cupertino, CA'}));
    });

    test('sends JSON Schema response format for structured output', () async {
      late String capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        final responsePayload = {
          'id': 'chatcmpl-json',
          'object': 'chat.completion',
          'created': 123456789,
          'model': 'qwen',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': '{"name":"Alice","age":30}',
              },
              'finish_reason': 'stop',
            },
          ],
          'usage': {
            'prompt_tokens': 8,
            'completion_tokens': 10,
            'total_tokens': 18,
          },
        };
        return http.Response(
          jsonEncode(responsePayload),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final plugin = omlx(
        httpClient: mockClient,
        models: const [OmlxModelDefinition(name: 'qwen')],
      );

      await plugin.init();
      final modelAction = plugin.resolve(ActionType.model, 'qwen') as Model;

      final response = await modelAction(
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'Alice is 30')],
            ),
          ],
          output: OutputConfig(
            schema: {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'age': {'type': 'integer'},
              },
              'required': ['name', 'age'],
            },
          ),
        ),
      );

      expect(response.text, equals('{"name":"Alice","age":30}'));

      final decoded = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(decoded['response_format'], isNotNull);
      expect(decoded['response_format']['type'], equals('json_schema'));
      expect(
        decoded['response_format']['json_schema']['schema']['properties']['name']['type'],
        equals('string'),
      );
    });
  });
}
