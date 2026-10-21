import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_omlx/genkit_omlx.dart';

void main() async {
  // 1. Initialize the oMLX plugin
  // Connects to local oMLX inference server running on Apple Silicon (default: http://localhost:8000)
  final plugin = omlx(
    baseUrl: 'http://localhost:8000',
    apiKey: 'sk-omlx-kjM1F8KZXQCvmB30RQyHjMVS',
    models: const [
      OmlxModelDefinition(
        name: 'Qwen9',
        model: 'mlx-community/Qwen3.5-9B-MLX-4bit',
      ),
      OmlxModelDefinition(
        name: 'Qwen27',
        model: 'mlx-community/Qwen3.8-27B-4bit',
      ),
      OmlxModelDefinition(
        name: 'kokoro',
        model: 'mlx-community/Kokoro-82M-bf16',
      ),
    ],
    embedders: const [
      OmlxEmbedderDefinition(
        name: 'bge-m3',
        model: 'mlx-community/bge-m3-mlx-4bit',
        dimensions: 384,
      ),
    ],
    rerankers: const [
      OmlxRerankerDefinition(
        name: 'bge-reranker',
        model: 'jinaai/jina-reranker-v3-mlx',
      ),
    ],
  );

  final ai = Genkit(plugins: [plugin]);

  print('=== 1. Basic Generation ===');
  try {
    final response = await ai.generate(
      model: omlx.model('Qwen9'),
      prompt: 'Explain Apple Silicon unified memory in two concise sentences.',
      config: OmlxGenerationConfig(temperature: 0.7),
    );
    print(response.text);
    print('Tokens used: ${response.usage?.totalTokens}\n');
  } catch (e) {
    print('Ensure oMLX is running locally: $e\n');
  }

  print('=== 2. Streaming Generation ===');
  try {
    final stream = ai.generateStream(
      model: omlx.model('Qwen9'),
      prompt: 'Write a short haiku about Apple M-series chips.',
    );

    await for (final chunk in stream) {
      stdout.write(chunk.text);
    }
    print('\n');
  } catch (e) {
    print('Streaming skipped: $e\n');
  }

  print('=== 3. Reasoning Models (<think> extraction) ===');
  try {
    final response = await ai.generate(
      model: omlx.model('Qwen9'),
      prompt: 'How many r\'s are in the word "strawberry"?',
    );

    final reasoning = response.message?.content
        .where((p) => p.isReasoning)
        .map((p) => p.reasoning)
        .firstOrNull;

    if (reasoning != null) {
      print('Reasoning:\n$reasoning\n');
    }
    print('Answer: ${response.text}\n');
  } catch (e) {
    print('Reasoning model test skipped: $e\n');
  }

  print('=== 4. Tool / Function Calling ===');
  try {
    final weatherTool = Tool<Map<String, dynamic>, String>(
      name: 'get_current_weather',
      description: 'Get current weather for a city',
      fn: (input, context) async {
        final location = input['location'] ?? 'Unknown';
        return ToolResult.response('Weather in $location is Sunny, 22°C');
      },
    );

    final response = await ai.generate(
      model: omlx.model('Qwen9'),
      prompt: 'What is the weather in Tokyo?',
      tools: [weatherTool],
    );
    print(response.text);
  } catch (e) {
    print('Tool call skipped: $e\n');
  }

  print('=== 5. Text Embeddings ===');
  try {
    final embeddings = await ai.embed(
      embedder: omlx.embedder('bge-m3'),
      document: DocumentData(
        content: [TextPart(text: 'Unified Memory Architecture')],
      ),
    );
    print(
      'Generated embedding vector of length: ${embeddings.first.embedding.length}\n',
    );
  } catch (e) {
    print('Embedding test skipped: $e\n');
  }

  print('=== 6. Text-to-Speech (TTS) ===');
  try {
    final speech = await ai.generate(
      model: omlx.speechModel(
        'kokoro',
        config: OmlxSpeechConfig(
          voice: 'af_heart',
          responseFormat: 'wav',
          speed: 1.0,
        ),
      ),
      prompt:
          'Apple Silicon delivers blazing fast inference with unified memory.',
    );

    final media = speech.media;
    if (media != null) {
      print('Synthesized audio MIME type: ${media.contentType}');
      final uri = Uri.parse(media.url);
      final audioBytes = uri.data?.contentAsBytes();
      if (audioBytes != null) {
        final outputFile = File('speech.wav');
        await outputFile.writeAsBytes(audioBytes);
        print(
          'Saved audio to: ${outputFile.path} (${audioBytes.length} bytes)\n',
        );
      }
    }
  } catch (e) {
    print('TTS skipped: $e\n');
  }

  print('=== 7. Document Reranking (Cross-Encoder) ===');
  try {
    const query = 'How does unified memory work on Apple Silicon?';
    final candidateTexts = [
      'Sourdough bread fermentation takes several hours at room temperature.',
      'Apple Silicon shares physical LPDDR5X unified memory across CPU, GPU, and Neural Engine with high bandwidth.',
      'The Eiffel Tower is located in Paris, France.',
      'Unified memory eliminates redundant copying between host system memory and dedicated GPU VRAM.',
    ];

    final ranked = await ai.rerank(
      reranker: omlx.reranker('bge-reranker'),
      query: query,
      texts: candidateTexts,
      options: OmlxRerankConfig(topN: 2),
    );

    print('Query: "$query"');
    print('Top ${ranked.length} ranked documents:');
    for (var i = 0; i < ranked.length; i++) {
      final doc = ranked[i];
      final text = doc.document.content
          .where((p) => p.isText)
          .map((p) => p.text)
          .join();
      print(
        '  #${i + 1} [score: ${doc.score.toStringAsFixed(4)}, orig_index: ${doc.index}] $text',
      );
    }
    print('');
  } catch (e) {
    print('Reranker skipped: $e\n');
  }

  await plugin.dispose();
  print('Done!');
}
