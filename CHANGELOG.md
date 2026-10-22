## 1.0.0

Initial stable release of `genkit_omlx`, providing an oMLX plugin for Genkit Dart powered by `domlx` (`^1.0.1`).

### Features
- **Plugin Handle (`omlx`)**:
  - Dynamic action discovery and registration for Chat/Vision models (`omlx/*`), Speech synthesis (`omlx/tts/*`), Audio transcription (`omlx/stt/*`), Text embeddings (`omlx/*`), and Document reranking (`omlx/*`).
  - Automatic `OMLX_API_KEY` environment variable fallback when `apiKey` is omitted or empty (`String.fromEnvironment('OMLX_API_KEY')`).
  - Pre-register models via `models: [...]` for immediate listing in the Genkit Developer UI.
- **Chat, Streaming, Reasoning & Multimodal Vision**:
  - Synchronous and streaming chat completions with `OmlxGenerationConfig` (`temperature`, `topP`, `topK`, `minP`, `maxTokens`, `presencePenalty`, `frequencyPenalty`, `repetitionPenalty`, `logitBias`, `seed`, `stopSequences`, `responseFormat`, `chatTemplateKwargs`, `extraBody`).
  - Native reasoning/chain-of-thought extraction (`ReasoningPart`) for models like DeepSeek-R1 and QwQ (`includeReasoning`).
  - Multimodal vision support (`MediaPart`) supporting `data:` URIs, local file paths (non-blocking async I/O), and `http(s)://` URLs.
  - Token usage and Apple Silicon KV cache telemetry (`cachedTokens` and `promptTokensDetails`).
- **Tool Calling**:
  - Automatic tool schema conversion (`toOmlxTools`) and tool call response extraction (`ToolRequestPart` / `ToolResponsePart`).
  - Configurable tool routing (`toolChoice`: `'auto'`, `'none'`, `'required'`) and targeted function invocation (`toolChoiceFunction`).
- **Embeddings & Reranking**:
  - Batch text embedding support via `omlx.embedder(...)` returning `OmlxEmbedderRef<OmlxEmbedConfig>` with support for `dimensions`, `encodingFormat` (`'float'` | `'base64'`), and `version`.
  - Document reranking via `omlx.rerank(...)` with `OmlxRerankConfig` (`topN`, `returnDocuments`) and relevance score metadata.
- **Audio Speech Synthesis (TTS) & Transcription (STT)**:
  - Text-to-Speech generation via `omlx.speechModel(...)` and `OmlxSpeechConfig` (`voice`, `responseFormat`, `speed`, `instructions`), returning base64 audio data URIs in `MediaPart`.
  - Speech-to-Text transcription via `omlx.transcriptionModel(...)` and `OmlxTranscriptionConfig` (`language`, `prompt`, `responseFormat`, `temperature`, `timestampGranularities`), supporting `data:` URIs and non-blocking local audio file reads.
- **Apple Silicon Unified Memory Management**:
  - Direct lifecycle helpers on `OmlxPluginHandle`: `listModels()`, `getMemoryStats()`, `unloadModel(modelId)`, and `clearCache()`.
- **Structured Error Mapping**:
  - Maps `OmlxApiException` HTTP status codes and semantic error codes (`insufficient_memory`, `model_not_found`, `context_length_exceeded`, `invalid_api_key`, `rate_limit_exceeded`, and `409` conflicts) to typed `GenkitException` `StatusCode`s.
