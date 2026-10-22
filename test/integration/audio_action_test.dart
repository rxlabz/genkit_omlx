import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:genkit/genkit.dart';
import 'package:genkit_omlx/genkit_omlx.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Speech-to-Text & Text-to-Speech Actions', () {
    group('omlx.speechModel (TTS)', () {
      test('synthesizes speech via /v1/audio/speech and returns base64 MediaPart', () async {
        late Map<String, dynamic> capturedBody;
        final fakeAudioBytes = Uint8List.fromList([0x52, 0x49, 0x46, 0x46]);

        final mockClient = MockClient((request) async {
          expect(request.method, equals('POST'));
          expect(request.url.path, equals('/v1/audio/speech'));
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response.bytes(
            fakeAudioBytes,
            200,
            headers: {'content-type': 'audio/wav'},
          );
        });

        final plugin = omlx(
          httpClient: mockClient,
          models: const [
            OmlxModelDefinition(
              name: 'kokoro',
              model: 'mlx-community/Kokoro-82M-bf16',
            ),
          ],
        );

        final ai = Genkit(plugins: [plugin]);
        final response = await ai.generate<void, OmlxSpeechConfig>(
          model: omlx.speechModel(
            'kokoro',
            config: OmlxSpeechConfig(
              voice: 'af_heart',
              responseFormat: 'wav',
              speed: 1.25,
            ),
          ),
          system: 'System instruction that should not be spoken',
          prompt: 'Hello from Apple Silicon!',
        );

        expect(capturedBody['model'], equals('mlx-community/Kokoro-82M-bf16'));
        expect(capturedBody['input'], equals('Hello from Apple Silicon!'));
        expect(capturedBody['voice'], equals('af_heart'));
        expect(capturedBody['response_format'], equals('wav'));
        expect(capturedBody['speed'], equals(1.25));

        expect(response.finishReason, equals(FinishReason.stop));
        final media = response.media;
        expect(media, isNotNull);
        expect(media!.contentType, equals('audio/wav'));
        expect(
          media.url,
          equals('data:audio/wav;base64,${base64Encode(fakeAudioBytes)}'),
        );
      });

      test('defaults voice to alloy and format to mp3 when config is omitted', () async {
        late Map<String, dynamic> capturedBody;
        final fakeMp3Bytes = Uint8List.fromList([0x49, 0x44, 0x33]);

        final mockClient = MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response.bytes(fakeMp3Bytes, 200);
        });

        final plugin = omlx(httpClient: mockClient);
        final ai = Genkit(plugins: [plugin]);

        // Dynamically resolved speech model via heuristic
        final response = await ai.generate<void, OmlxSpeechConfig>(
          model: omlx.speechModel('mlx-community/F5-TTS'),
          prompt: 'Default voice test',
        );

        expect(capturedBody['model'], equals('mlx-community/F5-TTS'));
        expect(capturedBody['voice'], equals('alloy'));
        expect(capturedBody['response_format'], equals('mp3'));
        expect(response.media?.contentType, equals('audio/mpeg'));
      });

      test('routes custom-named speech model via kind or ModelInfo supports.output = [media]', () async {
        var hitSpeechEndpoint = 0;
        final mockClient = MockClient((request) async {
          if (request.url.path == '/v1/audio/speech') {
            hitSpeechEndpoint++;
          }
          return http.Response.bytes([1, 2, 3], 200);
        });

        final plugin = omlx(
          httpClient: mockClient,
          models: [
            OmlxModelDefinition(
              name: 'my-voice',
              model: 'local/custom-voice-v1',
              modelInfo: ModelInfo(
                supports: {'output': ['media']},
              ),
            ),
            const OmlxModelDefinition(
              name: 'explicit-voice',
              model: 'local/custom-voice-v2',
              kind: OmlxModelKind.speech,
            ),
          ],
        );

        final ai = Genkit(plugins: [plugin]);
        await ai.generate<void, OmlxSpeechConfig>(
          model: omlx.speechModel('my-voice'),
          prompt: 'Synthesize me',
        );
        await ai.generate<void, OmlxSpeechConfig>(
          model: omlx.speechModel('explicit-voice'),
          prompt: 'Synthesize me too',
        );

        expect(hitSpeechEndpoint, equals(2));
      });

      test('validates speed range and responseFormat', () async {
        final mockClient = MockClient(
          (request) async => http.Response.bytes([1], 200),
        );
        final plugin = omlx(httpClient: mockClient);
        final action = plugin.resolve(
          ActionType.model,
          'mlx-community/Kokoro-82M-bf16',
        ) as Model;

        expect(
          () => action(
            ModelRequest(
              messages: [
                Message(role: Role.user, content: [TextPart(text: 'Too fast')]),
              ],
              config: {'speed': 10.0},
            ),
          ),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.status,
              'status',
              StatusCode.invalidArgument,
            ),
          ),
        );

        expect(
          () => action(
            ModelRequest(
              messages: [
                Message(
                  role: Role.user,
                  content: [TextPart(text: 'Unsupported format')],
                ),
              ],
              config: {'response_format': 'ogg'},
            ),
          ),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.status,
              'status',
              StatusCode.invalidArgument,
            ),
          ),
        );
      });

      test('throws INVALID_ARGUMENT when speech prompt is empty', () async {
        final mockClient = MockClient(
          (request) async => http.Response.bytes([1], 200),
        );
        final plugin = omlx(httpClient: mockClient);
        final action = plugin.resolve(
          ActionType.model,
          'mlx-community/Kokoro-82M-bf16',
        ) as Model;

        expect(
          () => action(
            ModelRequest(
              messages: [
                Message(role: Role.user, content: [TextPart(text: '   ')]),
              ],
            ),
          ),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.status,
              'status',
              StatusCode.invalidArgument,
            ),
          ),
        );
      });
    });

    group('omlx.transcriptionModel (STT)', () {
      test('transcribes base64 audio data URL via /v1/audio/transcriptions', () async {
        late String capturedContentType;
        late String capturedBodyText;

        final mockClient = MockClient((request) async {
          expect(request.method, equals('POST'));
          expect(request.url.path, equals('/v1/audio/transcriptions'));
          capturedContentType = request.headers['content-type'] ?? '';
          capturedBodyText = utf8.decode(request.bodyBytes, allowMalformed: true);
          return http.Response(
            jsonEncode({
              'text': 'Transcribed locally on M4 Max.',
              'language': 'en',
              'duration': 2.4,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final plugin = omlx(
          httpClient: mockClient,
          models: const [
            OmlxModelDefinition(
              name: 'whisper',
              model: 'mlx-community/whisper-large-v3-turbo',
            ),
          ],
        );

        final ai = Genkit(plugins: [plugin]);
        final audioBase64 = base64Encode([0x52, 0x49, 0x46, 0x46, 0x00, 0x01]);
        final response = await ai.generate<void, OmlxTranscriptionConfig>(
          model: omlx.transcriptionModel(
            'whisper',
            config: OmlxTranscriptionConfig(
              language: 'en',
              prompt: 'Apple Silicon benchmark',
              responseFormat: 'verbose_json',
              temperature: 0.0,
            ),
          ),
          messages: [
            Message(
              role: Role.user,
              content: [
                MediaPart(
                  media: Media(
                    url: 'data:audio/wav;base64,$audioBase64',
                    contentType: 'audio/wav',
                  ),
                ),
              ],
            ),
          ],
        );

        expect(capturedContentType, startsWith('multipart/form-data'));
        expect(capturedBodyText, contains('mlx-community/whisper-large-v3-turbo'));
        expect(capturedBodyText, contains('Apple Silicon benchmark'));
        expect(capturedBodyText, contains('verbose_json'));
        expect(capturedBodyText, contains('input.wav'));

        expect(response.text, equals('Transcribed locally on M4 Max.'));
        expect(response.raw?['language'], equals('en'));
        expect(response.raw?['duration'], equals(2.4));
      });

      test('transcribes local audio file path and handles plain-text srt/vtt/text output', () async {
        final tempDir = await Directory.systemTemp.createTemp('genkit_omlx_audio_test');
        addTearDown(() => tempDir.delete(recursive: true));

        final audioFile = File('${tempDir.path}/sample.mp3');
        await audioFile.writeAsBytes([0x49, 0x44, 0x33, 0x04]);

        const srtPayload = '1\n00:00:00,000 --> 00:00:02,000\nHello world\n';

        final mockClient = MockClient((request) async {
          // Plain text response (not JSON) when response_format is srt
          return http.Response(
            srtPayload,
            200,
            headers: {'content-type': 'text/plain'},
          );
        });

        final plugin = omlx(httpClient: mockClient);
        final ai = Genkit(plugins: [plugin]);

        final response = await ai.generate<void, OmlxTranscriptionConfig>(
          model: omlx.transcriptionModel(
            'mlx-community/whisper-large-v3-turbo',
            config: OmlxTranscriptionConfig(responseFormat: 'srt'),
          ),
          messages: [
            Message(
              role: Role.user,
              content: [
                MediaPart(
                  media: Media(url: audioFile.uri.toString()),
                ),
              ],
            ),
          ],
        );

        expect(response.text, equals(srtPayload));
        expect(response.raw?['format'], equals('srt'));
      });

      test('rejects non-audio media parts and remote HTTP URLs', () async {
        final mockClient = MockClient(
          (request) async => http.Response('{"text": "ok"}', 200),
        );
        final plugin = omlx(httpClient: mockClient);
        final action = plugin.resolve(
          ActionType.model,
          'mlx-community/whisper-large-v3-turbo',
        ) as Model;

        // Image media part instead of audio
        expect(
          () => action(
            ModelRequest(
              messages: [
                Message(
                  role: Role.user,
                  content: [
                    MediaPart(
                      media: Media(
                        url: 'data:image/png;base64,iVBORw0KGgo=',
                        contentType: 'image/png',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.status,
              'status',
              StatusCode.invalidArgument,
            ),
          ),
        );

        // Remote HTTP URL (not supported without downloading first)
        expect(
          () => action(
            ModelRequest(
              messages: [
                Message(
                  role: Role.user,
                  content: [
                    MediaPart(
                      media: Media(
                        url: 'https://example.com/sample.wav',
                        contentType: 'audio/wav',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.status,
              'status',
              StatusCode.invalidArgument,
            ),
          ),
        );
      });
    });
  });
}
