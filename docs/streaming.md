# AI SDK - Streaming Capabilities

## Overview

The Elixir AI SDK provides streaming capabilities for text generation, allowing you to receive AI model responses incrementally as they're generated instead of waiting for the complete response. This provides a more responsive user experience, especially for longer responses.

The SDK implements Server-Sent Events (SSE) streaming using a robust EventSource implementation based on Finch to efficiently process responses chunk by chunk in real-time with minimal memory overhead. This implementation properly handles backpressure, connection management, and parsing of the SSE protocol.

## Getting Started with Streaming

To use streaming with the AI SDK, you can use the `AI.stream_text/1` function, which works similarly to `AI.generate_text/1` but returns a stream of text chunks instead of a complete text response.

```elixir
{:ok, result} = AI.stream_text(%{
  model: AI.openai("gpt-3.5-turbo"),
  prompt: "Write a short story about a robot learning to paint."
})

# Access the stream from the result
stream = result.stream

# Process the stream - each chunk is a simple string
stream
|> Stream.each(&IO.write/1)  # Write each chunk as it arrives
|> Stream.run()  # Start consuming the stream

# Or collect all chunks into a single string
full_text = Enum.join(stream, "")
```

## Stream Format

The stream produces text chunks directly, making it easy to consume and work with. Each chunk is a string fragment of the model's response. The chunk size varies depending on the model and its tokenization.

These events are produced by parsing the Server-Sent Events (SSE) format returned by AI providers. The SDK handles all the complexities of SSE parsing, including multi-line data fields, JSON parsing, and event formatting.

## Examples

### Basic Streaming

```elixir
{:ok, result} = AI.stream_text(%{
  model: AI.openai("gpt-3.5-turbo"),
  prompt: "Explain how streaming works in LLMs."
})

result.stream
|> Stream.each(&IO.write/1)
|> Stream.run()
```

### With System Message

```elixir
{:ok, result} = AI.stream_text(%{
  model: AI.openai("gpt-3.5-turbo"),
  system: "You are a helpful assistant that responds in the style of Shakespeare.",
  prompt: "Tell me about the weather today."
})

result.stream
|> Stream.each(&IO.write/1)
|> Stream.run()
```

### Collecting the Full Response

If you want to collect all chunks into a single string:

```elixir
{:ok, result} = AI.stream_text(%{
  model: AI.openai("gpt-3.5-turbo"),
  prompt: "Write a haiku about programming."
})

full_text = Enum.join(result.stream, "")

IO.puts("Full response: #{full_text}")
```

### Error Handling

```elixir
case AI.stream_text(%{
  model: AI.openai("gpt-3.5-turbo"),
  prompt: "Tell me a joke."
}) do
  {:ok, result} ->
    # Simply process the text chunks
    result.stream
    |> Stream.each(&IO.write/1)
    |> Stream.run()

  {:error, error} ->
    IO.puts("Failed to start streaming: #{inspect(error)}")
end
```

The SDK handles several types of errors during streaming:
- Initial connection failures
- Network interruptions during streaming
- Invalid SSE format
- Timeouts (default: 30 seconds for initial connection)
- HTTP error responses from the provider
- Finch-related errors
- JSON parsing errors from malformed responses

All error conditions are properly propagated as `{:error, reason}` events in the stream or as an error response from the initial connection.

## Advanced Usage

### EventSource Implementation

The SDK uses a custom `AI.Provider.Utils.EventSource` module that implements the Server-Sent Events (SSE) protocol. This implementation:

- Creates and manages HTTP connections with proper headers
- Parses the SSE format according to specification
- Handles event reassembly from chunks
- Provides proper backpressure for efficient streaming
- Cleans up resources when the stream is done

### Custom Stream Processing

You can use all of Elixir's stream processing capabilities:

```elixir
{:ok, result} = AI.stream_text(%{
  model: AI.openai("gpt-3.5-turbo"),
  prompt: "List 10 programming languages."
})

result.stream
|> Stream.chunk_by(fn chunk -> chunk == "\n" end)
|> Stream.reject(fn chunk -> chunk == ["\n"] end)
|> Stream.map(fn chunks -> Enum.join(chunks, "") end)
|> Stream.each(fn line -> IO.puts("Language: #{line}") end)
|> Stream.run()
```

### Working with Phoenix LiveView

Streaming works especially well with Phoenix LiveView, allowing you to update the UI in real-time as responses are generated:

```elixir
def handle_event("generate", %{"prompt" => prompt}, socket) do
  # Start streaming in a separate process
  Task.async(fn ->
    case AI.stream_text(%{
      model: AI.openai("gpt-3.5-turbo"),
      prompt: prompt
    }) do
      {:ok, result} ->
        result.stream
        |> Stream.each(fn chunk ->
            # Send each chunk to the LiveView process
            send(self(), {:stream_chunk, chunk})
        end)
        |> Stream.run()
        
        send(self(), :stream_complete)
        
      {:error, error} ->
        send(self(), {:stream_error, error})
    end
  end)
  
  {:noreply, socket |> assign(generating: true, response: "")}
end

def handle_info({:stream_chunk, chunk}, socket) do
  # Append the new chunk to the existing response
  new_response = socket.assigns.response <> chunk
  {:noreply, socket |> assign(response: new_response)}
end

def handle_info(:stream_complete, socket) do
  {:noreply, socket |> assign(generating: false)}
end

def handle_info({:stream_error, error}, socket) do
  {:noreply, socket |> assign(generating: false, error: inspect(error))}
end
```

## API Reference

### `AI.stream_text/1`

```elixir
@spec stream_text(map()) :: {:ok, map()} | {:error, any()}
```

Options:

* `:model` - The language model to use
* `:system` - A system message that will be part of the prompt
* `:prompt` - A simple text prompt (can use either prompt or messages)
* `:messages` - A list of messages (can use either prompt or messages)
* `:max_tokens` - Maximum number of tokens to generate
* `:temperature` - Temperature setting for randomness
* `:top_p` - Nucleus sampling
* `:top_k` - Top-k sampling
* `:frequency_penalty` - Penalize new tokens based on their frequency
* `:presence_penalty` - Penalize new tokens based on their presence
* `:tools` - Tools that are accessible to and can be called by the model

Streaming-specific options:
* `:timeout` - Connection timeout in milliseconds (default: 30000)
* `:max_line_length` - Maximum length of an SSE line (default: 16384)
* `:retry_interval` - Time to wait before reconnecting in ms (default: 3000)
* `:test_mode` - For testing only, can be `:basic`, `:openai`, `:multi_line`, or `:error`

Returns:

* `{:ok, result}` - Success, with result containing:
  * `stream` - The stream of text chunks
  * `warnings` - Any warnings generated during processing
  * `provider_metadata` - Additional provider-specific metadata
  * `response` - The raw response from the provider

* `{:error, reason}` - Error with reason for failure

## Limitations and Future Improvements

* Tool calls via streaming are not yet fully supported
* Support for structured output streaming is planned for future releases
* Future enhancements will include:
  * Improved backpressure handling for very large responses
  * Automatic reconnection for temporary network issues
  * Progress tracking and statistics
  * Configurable stream processing pipelines
  * Additional providers beyond OpenAI

## Technical Implementation

The streaming functionality is built on several key components:

1. `AI.stream_text/1` - The main API entry point
2. `AI.Core.StreamText` - Core implementation of stream handling
3. `AI.Provider.Utils.EventSource` - SSE protocol implementation
4. Provider-specific `do_stream` implementations (e.g., OpenAI)

The SSE protocol implementation follows the [HTML5 EventSource specification](https://html.spec.whatwg.org/multipage/server-sent-events.html) and is compatible with the streaming APIs of major providers like OpenAI.