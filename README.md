# genkit_omlx

[![pub package](https://img.shields.io/badge/pub-v1.0.0-blue.svg)](https://pub.dev/packages/genkit_omlx)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A [Google Genkit](https://github.com/genkit-ai/genkit-dart) plugin for running local LLMs, embeddings, rerankers, and audio models on Apple Silicon via **[oMLX](https://github.com/jundot/omlx)** and **[domlx](https://github.com/rxlabz/domlx)**.

## Features

- **Apple Silicon Acceleration**: Harness macOS Unified Memory Architecture (UMA) and MLX for fast local inference with continuous batching and prefix caching.
- **Chat Completions & SSE Streaming**: Non-streaming and real-time Server-Sent Events (SSE) token streaming with inactivity timeout safety and mid-stream error detection.
- **Reasoning Models (`<think>` blocks)**: Native extraction and streaming of internal reasoning thoughts (DeepSeek-R1, Qwen 2.5/3.5, etc.) surfaced as Genkit `ReasoningPart`.
- **Tool & Function Calling**: Multi-turn tool execution with index-based streaming tool-call accumulation, automatic argument decoding, and specific function targeting (`toolChoiceFunction`).
- **Structured Outputs (JSON Schema)**: Constrained grammar generation using OpenAI-compatible JSON Schema validation (`outputSchema` / `outputFormat: 'json'`).
- **Text Embeddings**: Automatic batching (`maxEmbeddingBatchSize = 512`), vector dimension overrides, and float/base64 encoding via `/v1/embeddings`.
- **Semantic Document Reranking**: Cross-encoder document scoring and top-N ranking via `/v1/rerank` (`omlx.reranker(...)` and `ai.rerank(...)`).
- **Speech Synthesis (TTS) & Audio Transcription (STT)**: First-class support for local TTS models like Kokoro & F5-TTS (`omlx.speechModel(...)`) and Whisper STT (`omlx.transcriptionModel(...)`).
- **Dynamic Model Resolution & Discovery**: Resolve models on-the-fly (`omlx.model('...')`) and automatically discover models from `/v1/models` with modality-aware classification.
- **Unified Memory & Engine Lifecycle**: Inspect server health (`plugin.health()`), query per-model loaded memory status (`plugin.modelsStatus()`), and manually evict models from Apple Silicon unified memory (`plugin.unloadModel(...)`).

---

## Installation

Add `genkit_omlx` and `genkit` to your `pubspec.yaml`:

```yaml
dependencies:
  genkit: ^1.0.0
  genkit_omlx: ^1.0.0
```

---

## Quick Start

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_omlx/genkit_omlx.dart';

const apiKey = String.fromEnvironment('OMLX_API_KEY');

void main() async {
  // 1. Initialize plugin connecting to local oMLX server (default: http://localhost:8000)
  // Also reads OMLX_BASE_URL and OMLX_API_KEY environment variables by default.
  final plugin = omlx(
    baseUrl: 'http://localhost:8000',
    apiKey: apiKey,
    models: const [
      OmlxModelDefinition(
        name: 'Qwen9',
        model: 'mlx-community/Qwen3.5-9B-MLX-4bit',
      ),
    ],
  );

  final ai = Genkit(plugins: [plugin]);

  // 2. Generate text
  final response = await ai.generate(
    model: omlx.model('Qwen9'),
    prompt: 'Explain Apple Silicon unified memory in two concise sentences.',
    config: OmlxGenerationConfig(temperature: 0.7),
  );

  print(response.text);
  print('Tokens used: ${response.usage?.totalTokens}');

  await plugin.dispose();
}
```

---

## Usage Guide

### 1. Streaming Token Generation

```dart
final stream = ai.generateStream(
  model: omlx.model('Qwen9'),
  prompt: 'Write a short haiku about Apple M-series chips.',
);

await for (final chunk in stream) {
  stdout.write(chunk.text);
}

final finalResponse = await stream.onResult;
print('\nFinish reason: ${finalResponse.finishReason}');
```

### 2. Reasoning Models (`<think>` Extraction)

Reasoning models (such as DeepSeek-R1 and Qwen) emit intermediate thoughts in `<think>` blocks. `genkit_omlx` extracts these thoughts natively—both in synchronous responses and SSE streams—and surfaces them as Genkit `ReasoningPart`s:

```dart
final response = await ai.generate(
  model: omlx.model('Qwen9'),
  prompt: 'How many r\'s are in the word "strawberry"?',
);

final reasoning = response.message?.content
    .where((p) => p.isReasoning)
    .map((p) => p.reasoning)
    .firstOrNull;

if (reasoning != null) {
  print('Internal thoughts:\n$reasoning\n');
}

print('Final answer: ${response.text}');
```

### 3. Tool / Function Calling

```dart
final weatherTool = Tool<Map<String, dynamic>, String>(
  name: 'get_current_weather',
  description: 'Get the current weather for a city',
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
```

### 4. Multimodal Vision Input (Images)

Pass base64 data URIs, remote HTTP image URLs, or local image files (`file://` or file paths) via `MediaPart`:

```dart
final response = await ai.generate(
  model: omlx.model('mlx-community/Qwen3-VL-8B-Instruct-4bit'),
  promptParts: [
    TextPart(text: 'Describe what you see in this diagram.'),
    MediaPart(
      media: Media(
        contentType: 'image/png',
        url: 'file:///path/to/diagram.png',
      ),
    ),
  ],
);

print(response.text);
```

### 5. Text Embeddings

```dart
final plugin = omlx(
  embedders: const [
    OmlxEmbedderDefinition(
      name: 'bge-m3',
      model: 'mlx-community/bge-m3-mlx-4bit',
      dimensions: 384,
    ),
  ],
);

final ai = Genkit(plugins: [plugin]);

final embeddings = await ai.embed(
  embedder: omlx.embedder('bge-m3'),
  document: DocumentData(
    content: [TextPart(text: 'Unified Memory Architecture')],
  ),
  options: OmlxEmbedConfig(dimensions: 384),
);

print('Embedding dimensions: ${embeddings.first.embedding.length}');
```

### 6. Semantic Document Reranking (`/v1/rerank`)

Score and rank candidate documents or plain texts against a query using local cross-encoder rerankers:

```dart
final plugin = omlx(
  rerankers: const [
    OmlxRerankerDefinition(
      name: 'reranker',
      model: 'jinaai/jina-reranker-v3-mlx',
    ),
  ],
);

final ai = Genkit(plugins: [plugin]);

final ranked = await ai.rerank(
  reranker: omlx.reranker('bge-reranker'),
  query: 'How does unified memory work on Apple Silicon?',
  texts: [
    'Sourdough bread fermentation takes several hours at room temperature.',
    'Apple Silicon shares physical LPDDR5X unified memory across CPU, GPU, and Neural Engine.',
    'Unified memory eliminates redundant copying between system RAM and GPU VRAM.',
  ],
  options: OmlxRerankConfig(topN: 2),
);

for (final item in ranked) {
  print('[score: ${item.score.toStringAsFixed(4)}, index: ${item.index}] ${item.document.text}');
}
```

### 7. Speech Synthesis (TTS) & Audio Transcription (STT)

#### Text-to-Speech (`/v1/audio/speech`)

Synthesize text into audio using `omlx.speechModel(...)`. Returns a `MediaPart` containing a base64 audio data URI:

```dart
final speech = await ai.generate(
  model: omlx.speechModel(
    'mlx-community/Kokoro-82M-bf16',
    config: OmlxSpeechConfig(
      voice: 'af_heart',
      responseFormat: 'wav',
      speed: 1.0,
    ),
  ),
  prompt: 'Apple Silicon delivers blazing fast local inference.',
);

final audioBytes = Uri.parse(speech.media!.url).data!.contentAsBytes();
await File('speech.wav').writeAsBytes(audioBytes);
```

#### Speech-to-Text (`/v1/audio/transcriptions`)

Transcribe base64 audio data URIs or local audio files using `omlx.transcriptionModel(...)`:

```dart
final transcript = await ai.generate(
  model: omlx.transcriptionModel(
    'mlx-community/whisper-large-v3-turbo',
    config: OmlxTranscriptionConfig(
      language: 'en',
      responseFormat: 'verbose_json',
    ),
  ),
  promptParts: [
    MediaPart(
      media: Media(
        contentType: 'audio/wav',
        url: 'file:///path/to/recording.wav',
      ),
    ),
  ],
);

print('Transcript: ${transcript.text}');
```

### 8. Unified Memory & Server Lifecycle Management

Monitor server health, check which models are loaded in Apple Silicon unified memory, and explicitly evict models when switching workloads:

```dart
// 1. Check server health and engine pool
final health = await plugin.health();
print('Server healthy: ${health.isHealthy} (version: ${health.version})');

// 2. Inspect loaded models in unified memory
final statuses = await plugin.modelsStatus();
for (final status in statuses) {
  print('${status.modelId}: loaded=${status.isLoaded}');
}

// 3. Evict a model by its Genkit alias or wire model ID
final unloadResult = await plugin.unloadModel('qwen');
print('Unloaded ${unloadResult.modelId}: ${unloadResult.success}');
```

---

## Configuration Reference

### `OmlxGenerationConfig`

| Field | Type | Description |
|---|---|---|
| `version` | `String?` | Wire model identifier or quantization override |
| `temperature` | `double?` | Sampling temperature (`0.0` – `2.0`) |
| `topP` | `double?` | Nucleus sampling probability cutoff (`0.0` – `1.0`) |
| `topK` | `int?` | Top-K sampling cutoff (`>= 1`) |
| `repetitionPenalty` | `double?` | Repetition penalty factor (`>= 0.0`) |
| `maxTokens` | `int?` | Maximum tokens to generate (`>= 1`) |
| `stop` | `List<String>?` | Custom stop sequences |
| `user` | `String?` | Optional end-user identifier for tracking |
| `jsonMode` | `bool?` | Forces `{"type": "json_object"}` response format |
| `strictJsonSchema` | `bool?` | Enforces strict JSON Schema validation (default `false`) |
| `toolChoiceFunction` | `String?` | Forces the model to call a specific tool function by name |
| `extra` | `Map<String, dynamic>?` | Additional vendor-specific parameters passed to oMLX |

### `OmlxEmbedConfig`

| Field | Type | Description |
|---|---|---|
| `version` | `String?` | Wire model identifier override |
| `dimensions` | `int?` | Output vector dimensions (`>= 1`) |
| `encodingFormat` | `String?` | Vector encoding format (`'float'` or `'base64'`) |
| `user` | `String?` | Optional end-user identifier |

### `OmlxRerankConfig`

| Field | Type | Description |
|---|---|---|
| `version` | `String?` | Wire model identifier override |
| `topN` | `int?` | Maximum number of top-scoring documents to return (`>= 1`) |
| `returnDocuments` | `bool?` | Whether to include document text in the response (default `true`) |

### `OmlxSpeechConfig`

| Field | Type | Description |
|---|---|---|
| `version` | `String?` | Wire model identifier override |
| `voice` | `String?` | Voice identifier (default `'alloy'`, e.g. `'af_heart'`) |
| `responseFormat` | `String?` | Audio format: `'mp3'` (default), `'wav'`, `'opus'`, `'aac'`, `'flac'`, `'pcm'` |
| `speed` | `double?` | Playback speed multiplier (`0.25` – `4.0`) |

### `OmlxTranscriptionConfig`

| Field | Type | Description |
|---|---|---|
| `version` | `String?` | Wire model identifier override |
| `language` | `String?` | ISO-639-1 language code (e.g. `'en'`, `'fr'`) |
| `prompt` | `String?` | Optional vocabulary or style hint for the decoder |
| `responseFormat` | `String?` | Transcript format: `'json'` (default), `'text'`, `'srt'`, `'verbose_json'`, `'vtt'` |
| `temperature` | `double?` | Sampling temperature (`0.0` – `1.0`) |

---

## Error Mapping

`genkit_omlx` maps `domlx` exceptions onto canonical `GenkitException` status codes:

| oMLX / HTTP Condition | `GenkitException` Status |
|---|---|
| HTTP `507` or `code == 'insufficient_memory'` (Apple Silicon UMA OOM) | `StatusCode.resourceExhausted` |
| HTTP `429` or `code == 'rate_limit_exceeded'` | `StatusCode.resourceExhausted` |
| HTTP `409` (Model loading / swap conflict) | `StatusCode.aborted` |
| HTTP `404` or `code == 'model_not_found'` | `StatusCode.notFound` |
| HTTP `401` or `code == 'invalid_api_key'` | `StatusCode.unauthenticated` |
| HTTP `400` or `code == 'context_length_exceeded'` | `StatusCode.invalidArgument` |
| Request or SSE stream inactivity `TimeoutException` | `StatusCode.deadlineExceeded` |
| Connection / socket failures (`OmlxNetworkException`) | `StatusCode.unavailable` |

---

## License

MIT License. See [LICENSE](LICENSE) for details.
