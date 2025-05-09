# Elixir AI SDK

An Elixir port of the [Vercel AI SDK](https://ai-sdk.dev/), designed to help you build AI-powered applications using Elixir and Phoenix.

## Features

- **Text Generation**: Generate text using Large Language Models (LLMs)
- **Real-time Streaming**: Stream text responses chunk-by-chunk as they're generated
- **Server-Sent Events (SSE)**: Efficient streaming with proper backpressure handling
- **Tool Calling**: Call tools and functions from LLMs
- **Provider Support**: Support for popular AI providers (OpenAI, Anthropic, etc.)
- **Elixir Integration**: Seamless integration with Elixir's Stream API

## Installation

```elixir
def deps do
  [
    {:ai_sdk, "~> 0.1.0"}
  ]
end
```

## Usage Examples

### Text Generation

```elixir
{:ok, result} = AI.generate_text(%{
  model: AI.openai("gpt-4o"),
  system: "You are a friendly assistant!",
  prompt: "Why is the sky blue?"
})

IO.puts(result.text)
```

### Streaming Text Generation

```elixir
{:ok, result} = AI.stream_text(%{
  model: AI.openai("gpt-4o"),
  system: "You are a friendly assistant!",
  prompt: "Why is the sky blue?"
})

# Process chunks as they arrive (safely with proper termination)
r = Enum.reduce_while(result.stream, [], fn
  # Text chunk received - print it and continue
  {:text_delta, chunk}, acc ->
    IO.write(chunk)
    {:cont, [chunk | acc]}
    
  # Stream finished - print reason and halt collection
  {:finish, reason}, acc ->
    IO.puts("\nFinished: #{reason}")
    {:halt, acc}
    
  # Error received - print it and halt collection
  {:error, error}, acc ->
    IO.puts("\nError: #{inspect(error)}")
    {:halt, acc}
    
  # Other events - just continue
  _, acc ->
    {:cont, acc}
end)

IO.inspect(r, label: "Collected chunks")
```

## Architecture

The Elixir AI SDK follows similar patterns to the original Vercel AI SDK but uses Elixir idioms and patterns:

- Stream-based API for real-time text generation
- Server-Sent Events (SSE) for efficient streaming
- Proper backpressure handling for large responses
- Elixir-native error handling with tagged tuples
- Phoenix integration for web applications

## Development Status

This project is under active development. See the [project roadmap](ROADMAP.md) for more information.

## Documentation

- [Getting Started](docs/getting-started.md)
- [Streaming Guide](docs/streaming.md) - Real-time text generation with SSE
- [Tool Calling](docs/tool-calling.md) - Function calling capabilities
- [Provider Integration](docs/providers.md) - Using different AI providers