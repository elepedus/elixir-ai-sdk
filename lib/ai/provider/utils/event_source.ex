defmodule AI.Provider.Utils.EventSource do
  @moduledoc """
  Utility functions for handling Server-Sent Events (SSE).

  This module provides functionality for making HTTP requests that receive
  Server-Sent Events (SSE) responses, commonly used for streaming API responses
  from AI providers like OpenAI.
  
  The EventSource module handles:
  
  * Creating HTTP connections with proper SSE headers
  * Parsing SSE format (data:, event:, id:, retry: fields)
  * Converting SSE events into structured Elixir stream events
  * Supporting backpressure for efficient streaming
  * Error handling and connection cleanup
  """
  

  @typedoc """
  Response from an SSE request
  
  * `{:ok, response}` - Successful response with status, body, and stream
  * `{:error, reason}` - Error occurred during connection or streaming
  """
  @type response :: {:ok, %{status: integer(), body: binary(), stream: Stream.t()}} | {:error, term()}
  
  @typedoc """
  Stream events that can be emitted by an SSE stream
  
  * `{:text_delta, text}` - A chunk of text from the model
  * `{:finish, reason}` - Stream has completed with reason (e.g., "stop", "length")
  * `{:metadata, data}` - Additional metadata from the model
  * `{:error, reason}` - An error occurred during streaming
  """
  @type stream_event :: 
    {:text_delta, String.t()} | 
    {:finish, String.t()} | 
    {:metadata, map()} | 
    {:error, term()}

  # Default timeout for the initial connection
  @connection_timeout 30_000
  
  # Default retry interval
  @default_retry 3000
  
  # Default max line length
  @default_max_line_length 16384

  @doc """
  Makes a POST request to the specified URL with streaming response.

  This function sends a POST request with the provided body and headers to the URL,
  and returns a structure that can be used to stream the SSE responses. The returned
  stream emits events of type `stream_event()`.

  ## Parameters

    * `url` - The URL to make the request to
    * `body` - The JSON request body
    * `headers` - HTTP headers to include in the request
    * `options` - Additional options for the request:
        * `:timeout` - Connection timeout in milliseconds (default: 30000)
        * `:max_line_length` - Maximum length of an SSE line (default: 16384)
        * `:retry_interval` - Time to wait before reconnecting in ms (default: 3000)

  ## Returns

    * `{:ok, response}` - Where response contains:
      * `status` - HTTP status code
      * `body` - Response body (usually just initialization message)
      * `stream` - Stream of `stream_event()` events
    * `{:error, reason}` - If the request fails

  ## Examples

      {:ok, response} = EventSource.post(
        "https://api.openai.com/v1/chat/completions",
        %{model: "gpt-3.5-turbo", messages: [%{role: "user", content: "Hello"}], stream: true},
        %{"Authorization" => "Bearer my-api-key", "Content-Type" => "application/json"},
        %{timeout: 60_000}
      )

      response.stream
      |> Stream.each(fn
        {:text_delta, chunk} -> IO.write(chunk)
        {:finish, reason} -> IO.puts("\\nFinished: \#{reason}")
        {:error, error} -> IO.puts("Error: \#{inspect(error)}")
        _ -> :ok
      end)
      |> Stream.run()
  """
  @spec post(String.t(), map(), map(), map()) :: response()
  def post(url, body, headers, options) do
      # Use real implementation
      post_real(url, body, headers, options)
  end

  @spec post_real(String.t(), map(), map(), map()) :: response()
  # Real implementation using Finch for production
  defp post_real(url, body, headers, options) do
    # Ensure Finch is started
    case ensure_finch_started() do
      :ok ->
        try do
          # Create a Finch request with proper streaming headers
          all_headers = 
            headers
            |> Map.put("Content-Type", "application/json")
            |> Map.put("Accept", "text/event-stream")
            # Convert map to list of tuples for Finch
            |> Enum.map(fn {k, v} -> {k, v} end)

          # Encode the body to JSON
          encoded_body = Jason.encode!(body)

          # Extract options
          timeout = Map.get(options, :timeout, @connection_timeout)
          max_line_length = Map.get(options, :max_line_length, @default_max_line_length)
          retry_interval = Map.get(options, :retry_interval, @default_retry)

          # Create the stream configuration
          stream_options = %{
            url: url,
            body: encoded_body,
            headers: all_headers,
            timeout: timeout,
            max_line_length: max_line_length,
            retry_interval: retry_interval,
            ref: make_ref(),
            owner: self()
          }

          # Create a stream that processes SSE events
          stream = 
            Stream.resource(
              # Initialization function
              fn -> initialize_sse_stream(stream_options) end,
              # Producer function
              fn state -> get_next_event(state) end,
              # Cleanup function
              fn state -> cleanup_stream(state) end
            )

          # Return the stream
          {:ok, %{
            status: 200, 
            body: "SSE stream initialized",
            stream: stream
          }}
        catch
          kind, error ->
            formatted_error = Exception.format(kind, error, __STACKTRACE__)
            {:error, "Failed to initialize SSE stream: #{formatted_error}"}
        end

      {:error, error} ->
        {:error, "Failed to start Finch: #{inspect(error)}"}
    end
  end
  
  @spec ensure_finch_started() :: :ok | {:error, term()}
  # Ensure Finch is started
  defp ensure_finch_started do
    if Process.whereis(AI.Finch) do
      :ok
    else
      # Try to start Finch if not running
      case Application.ensure_all_started(:finch) do
        {:ok, _} ->
          # Application started, now start Finch process
          case Finch.start_link(name: AI.Finch) do
            {:ok, _} -> :ok
            {:error, {:already_started, _}} -> :ok
            error -> error
          end
        error -> error
      end
    end
  end
  
  @spec initialize_sse_stream(map()) :: map()
  # Initialize the SSE stream connection
  defp initialize_sse_stream(options) do
    # Build the Finch request
    request = Finch.build(:post, options.url, options.headers, options.body)
    
    # Start a process to handle the stream connection
    stream_pid = spawn_link(fn -> 
      Process.flag(:trap_exit, true)
      # Start the actual streaming request
      start_streaming_request(request, options)
      # Keep the process alive until it's explicitly terminated
      receive do
        {:EXIT, _, _} -> :ok
      end
    end)
    
    # Initial state
    %{
      buffer: "",
      data: [],
      event: nil,
      id: nil,
      retry: options.retry_interval,
      status: :connecting,
      stream_pid: stream_pid,
      owner: options.owner,
      ref: options.ref,
      max_line_length: options.max_line_length,
      error: nil,
      finished: false
    }
  end
  
  @spec start_streaming_request(Finch.Request.t(), map()) :: :ok
  # Start the streaming request to the server
  defp start_streaming_request(request, options) do
    if Code.ensure_loaded?(Finch) do
      try do
        # Define callback function for stream processing
        callback = fn
          {:status, status} ->
            send(options.owner, {:sse_status, options.ref, status})
          {:headers, headers} ->
            send(options.owner, {:sse_headers, options.ref, headers})
          {:data, data} ->
            send(options.owner, {:sse_data, options.ref, data})
          :done ->
            send(options.owner, {:sse_done, options.ref})
          {:error, error} ->
            send(options.owner, {:sse_error, options.ref, error})
        end
        
        # Start the Finch stream with callback
        _finch_opts = [receive_timeout: options.timeout]
        
        # Call the Finch.stream function directly
        case Finch.stream(request, AI.Finch, options.ref, callback) do
          {:ok, _ref} -> :ok
          {:error, error} -> send(options.owner, {:sse_error, options.ref, error})
        end
      rescue
        e ->
          # Handle any errors during Finch setup
          send(options.owner, {:sse_error, options.ref, {:finch_error, e}})
      end
    else
      # Finch not available
      send(options.owner, {:sse_error, options.ref, :finch_not_loaded})
    end
  end
  
  # This function is kept for reference only, not used in current implementation
  
  # This function is no longer needed as we use callback style
  # instead of message passing for Finch.stream
  
  @spec get_next_event(map()) :: {[stream_event()], map()} | {:halt, map()}
  # Get the next event from the stream
  defp get_next_event(%{error: error} = state) when not is_nil(error) do
    # If we have an error, emit it and stop
    {[{:error, error}], %{state | finished: true}}
  end
  
  defp get_next_event(%{finished: true} = state) do
    # Stream is done
    {:halt, state}
  end
  
  defp get_next_event(state) do
    # Wait for the next message
    receive do
      {:sse_status, ref, status} when ref == state.ref ->
        if status >= 400 do
          # HTTP error
          error = "HTTP request failed with status #{status}"
          {[{:error, error}], %{state | error: error, finished: true}}
        else
          # Status OK, continue
          get_next_event(%{state | status: :connected})
        end
        
      {:sse_headers, ref, _headers} when ref == state.ref ->
        # Headers received, continue
        get_next_event(state)
        
      {:sse_data, ref, data} when ref == state.ref ->
        # Process data chunk
        process_data_chunk(state, data)
        
      {:sse_done, ref} when ref == state.ref ->
        # Stream complete, emit any remaining data
        events = if state.data != [], do: [format_sse_event(state)], else: []
        events = events ++ [{:finish, "complete"}]
        {events, %{state | finished: true}}
        
      {:sse_error, ref, error} when ref == state.ref ->
        # Stream error
        {[{:error, error}], %{state | error: error, finished: true}}
        
      after 10000 ->
        # Timeout after 10 seconds of inactivity
        error = "SSE stream timeout after 10 seconds of inactivity"
        {[{:error, error}], %{state | error: error, finished: true}}
    end
  end
  
  @spec process_data_chunk(map(), binary()) :: {[stream_event()], map()}
  # Process a chunk of SSE data
  defp process_data_chunk(state, chunk) do
    # Append chunk to buffer
    buffer = state.buffer <> chunk
    
    # Process lines in the buffer
    process_buffer_lines(state, buffer, [])
  end
  
  @spec process_buffer_lines(map(), binary(), [stream_event()]) :: {[stream_event()], map()}
  # Process buffer line by line
  defp process_buffer_lines(state, buffer, events) do
    case String.split(buffer, "\n", parts: 2) do
      [line, rest] ->
        # Process this line
        {new_state, new_events} = process_sse_line(state, String.trim_trailing(line))
        # Continue with rest of buffer
        process_buffer_lines(new_state, rest, events ++ new_events)
        
      [remaining] ->
        # No complete line yet, store in buffer
        {events, %{state | buffer: remaining}}
    end
  end
  
  @spec process_sse_line(map(), binary()) :: {map(), [stream_event()]}
  # Process a single SSE line
  defp process_sse_line(state, "") do
    # Empty line signals end of event
    if state.data != [] do
      # We have data to emit
      event = format_sse_event(state)
      # Reset event data
      {%{state | data: [], event: nil}, [event]}
    else
      # No data to emit
      {state, []}
    end
  end
  
  defp process_sse_line(state, line) do
    cond do
      # Skip comments
      String.starts_with?(line, ":") ->
        {state, []}
        
      # Event field
      String.starts_with?(line, "event:") ->
        event = String.trim(String.slice(line, 6..-1//1))
        {%{state | event: event}, []}
        
      # Data field
      String.starts_with?(line, "data:") ->
        data = String.trim(String.slice(line, 5..-1//1))
        {%{state | data: state.data ++ [data]}, []}
        
      # ID field
      String.starts_with?(line, "id:") ->
        id = String.trim(String.slice(line, 3..-1//1))
        {%{state | id: id}, []}
        
      # Retry field
      String.starts_with?(line, "retry:") ->
        retry_str = String.trim(String.slice(line, 6..-1//1))
        case Integer.parse(retry_str) do
          {retry, _} -> {%{state | retry: retry}, []}
          :error -> {state, []}
        end
        
      # Unknown field, ignore
      true ->
        {state, []}
    end
  end
  
  @spec format_sse_event(map()) :: stream_event()
  # Format an SSE event from the current state
  defp format_sse_event(state) do
    # Join data lines
    data_str = Enum.join(state.data, "\n")
    
    # Try to parse as JSON
    case parse_json_data(data_str) do
      {:ok, parsed_data} ->
        format_parsed_json_event(parsed_data, state.event)
        
      :error ->
        # Not JSON, treat as raw text
        {:text_delta, data_str}
    end
  end
  
  @spec parse_json_data(binary()) :: {:ok, map()} | :error
  # Try to parse data as JSON
  defp parse_json_data("") do
    :error
  end
  
  defp parse_json_data(data_str) do
    try do
      {:ok, Jason.decode!(data_str)}
    rescue
      _ -> :error
    end
  end
  
  @spec format_parsed_json_event(map(), String.t() | nil) :: stream_event()
  # Format parsed JSON event (handles OpenAI format)
  defp format_parsed_json_event(data, _event_type) do
    # Try to extract content delta if this is OpenAI format
    case get_in(data, ["choices", Access.at(0), "delta", "content"]) do
      nil -> 
        # Check if this is a finish event
        finish_reason = get_in(data, ["choices", Access.at(0), "finish_reason"])
        if not is_nil(finish_reason) and finish_reason != "" do
          {:finish, finish_reason}
        else
          # Just metadata
          {:metadata, data}
        end
        
      content -> 
        # Text content delta
        {:text_delta, content}
    end
  end
  
  @spec cleanup_stream(map()) :: :ok
  # Cleanup the stream
  defp cleanup_stream(state) do
    # Terminate stream process if it's still running
    if Map.has_key?(state, :stream_pid) and is_pid(state.stream_pid) and Process.alive?(state.stream_pid) do
      Process.exit(state.stream_pid, :normal)
    end
    
    # Drain any remaining messages
    drain_messages(state.ref)
    
    :ok
  end
  
  @spec drain_messages(reference()) :: :ok
  # Drain remaining messages for this stream
  defp drain_messages(ref) do
    receive do
      {type, ^ref, _} when type in [:sse_data, :sse_status, :sse_headers, :sse_error] ->
        drain_messages(ref)
      {:sse_done, ^ref} ->
        drain_messages(ref)
    after
      0 -> :ok
    end
  end
end
