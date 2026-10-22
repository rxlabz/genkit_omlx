# genkit_omlx

A [Google Genkit](https://github.com/genkit-ai/genkit-dart) plugin for running local LLMs and embeddings on Apple Silicon via **[oMLX](https://github.com/jundot/omlx)** and **[domlx](https://github.com/rxlabz/domlx)**.

## Features

- **Apple Silicon Acceleration**: Harness macOS Unified Memory Architecture (UMA) and MLX for fast local inference.
- **Full Chat Completion & Streaming**: Non-streaming and real-time Server-Sent Events (SSE) token streaming with inactivity timeout safety.
- **Reasoning Models (`<think>` blocks)**: First-class extraction and streaming of internal reasoning content (e.g. DeepSeek-R1, Qwen 2.5) surfaced as Genkit `ReasoningPart`.
- **Tool & Function Calling**: Multi-turn tool execution with automatic argument decoding and message history normalization.
- **Structured Outputs (JSON Schema)**: Constrained grammar generation using OpenAI-compatible JSON Schema validation.
- **Text Embeddings**: Batch embedding vector generation via `/v1/embeddings`.
- **Speech Synthesis (TTS) & Audio Transcription (STT)**: Direct support for Kokoro/F5-TTS (`omlx.speechModel(...)`) and Whisper (`omlx.transcriptionModel(...)`).
- **Semantic Document Reranking**: Cross-encoder document scoring via `/v1/rerank` (`omlx.reranker(...)` / `ai.rerank(...)`).
- **Dynamic Model Resolution**: Resolve models on-the-fly (`omlx.model('...')`) without requiring upfront registration.
- **Unified Memory & Model Lifecycle**: Health inspection (`plugin.health()`), engine status (`plugin.modelsStatus()`), and explicit memory eviction (`plugin.unloadModel(...)`).

---

## Installation

Add `genkit_omlx` and `genkit` to your `pubspec.yaml`:

```yaml
dependencies:
  genkit: ^1.0.0
  genkit_omlx:
    path: path/to/genkit_omlx
```

---

## Quick Start

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_omlx/genkit_omlx.dart';

void main() async {
  // 1. Initialize plugin connecting to local oMLX server (default: http://localhost:8000)
  final plugin = omlx(
    baseUrl: 'http://localhost:8000',
    // apiKey: 'optional-bearer-token',
    models: const [
      OmlxModelDefinition(
        name: 'qwen',
        model: 'mlx-community/Qwen2.5-7B-Instruct-4bit',
      ),
    ],
  );

  final ai = Genkit(plugins: [plugin]);

  // 2. Generate text
  final response = await ai.generate(
    model: omlx.model('qwen'),
    prompt: 'Explain continuous batching in one paragraph.',
    config: const OmlxGenerationConfig(temperature: 0.7),
  );

  print(response.text);

  await plugin.dispose();
}
```

---

## Key Scenarios

### 1. Streaming Token Generation

```dart
final stream = ai.generateStream(
  model: omlx.model('qwen'),
  prompt: 'Write a short story about an astronaut.',
);

await for (final chunk in stream) {
  stdout.write(chunk.text);
}
```

### 2. Reasoning Models (DeepSeek-R1, Qwen 2.5)

Reasoning models wrap intermediate thoughts in `<think>` blocks. `genkit_omlx` extracts these thoughts natively and surfaces them in `ReasoningPart`:

```dart
final response = await ai.generate(
  model: omlx.model('deepseek-r1-distill-qwen-7b'),
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
    return 'Weather in $location is Sunny, 21°C';
  },
);

final response = await ai.generate(
  model: omlx.model('qwen'),
  prompt: 'What is the weather in Tokyo?',
  tools: [weatherTool],
);

print(response.text);
```

### 4. Structured Output (JSON Schema)

```dart
final response = await ai.generate(
  model: omlx.model('qwen'),
  prompt: 'Extract: John is a 32 year old engineer in Berlin.',
  output: const OutputConfig(
    schema: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'age': {'type': 'integer'},
        'city': {'type': 'string'},
      },
      'required': ['name', 'age', 'city'],
    },
  ),
);

print(response.text); // Guaranteed JSON matching the schema
```

### 5. Text Embeddings

```dart
final plugin = omlx(
  embedders: const [
    OmlxEmbedderDefinition(name: 'bge-micro', dimensions: 384),
  ],
);

final ai = Genkit(plugins: [plugin]);

final embeddings = await ai.embed(
  embedder: omlx.embedder('bge-micro'),
  document: DocumentData(
    content: [TextPart(text: 'Unified Memory Architecture')],
  ),
);

print('Embedding dimensions: ${embeddings.embedding.length}');
```

---

## Configuration Reference

### `OmlxGenerationConfig`

| Field | Type | Description |
|---|---|---|
| `temperature` | `double?` | Sampling temperature (default `1.0`) |
| `topP` | `double?` | Nucleus sampling probability cutoff |
| `topK` | `int?` | Top-K sampling cutoff |
| `repetitionPenalty`| `double?` | Penalty factor for repeated tokens |
| `maxTokens` | `int?` | Maximum tokens to generate |
| `stop` | `List<String>?` | Custom stop sequences |
| `user` | `String?` | Optional user tracking identifier |
| `extra` | `Map<String, dynamic>?`| Additional custom parameters passed to oMLX |

---

## License

MIT License. See [LICENSE](LICENSE) for details.
