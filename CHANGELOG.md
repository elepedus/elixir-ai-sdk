# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1-rc.0] - 2025-01-29

### Added

- Initial release candidate of the Elixir AI SDK
- Core text generation functionality with `AI.generate_text/1`
- Real-time streaming support with `AI.stream_text/1`
- Server-Sent Events (SSE) implementation for efficient streaming
- OpenAI provider support (GPT-3.5, GPT-4, GPT-4o models)
- OpenAI-compatible provider support for local LLMs (LM Studio, Ollama, etc.)
- Comprehensive test suite based on Vercel AI SDK tests
- Stream event types: text_delta, tool_call, finish, error
- Proper backpressure handling for streaming responses
- Mode option for stream_text to return either raw strings or event tuples
- Mock language model for testing purposes

### Features

- **Text Generation**: Generate text using Large Language Models
- **Streaming**: Real-time text generation with chunk-by-chunk delivery
- **Provider Support**: OpenAI and OpenAI-compatible providers
- **Elixir Integration**: Native integration with Elixir's Stream API
- **Error Handling**: Comprehensive error handling with tagged tuples

### Known Limitations

- This is a release candidate and API may change before stable release
- Tool calling implementation is in progress
- Limited to text generation (no image/audio generation yet)
- Provider support limited to OpenAI-compatible APIs

### Dependencies

- Elixir ~> 1.15
- Tesla ~> 1.7 (HTTP client)
- Jason ~> 1.4 (JSON handling)
- Finch ~> 0.16 (HTTP adapter)

[0.0.1-rc.0]: https://github.com/elepedus/elixir-ai-sdk/releases/tag/v0.0.1-rc.0