defmodule AI.Providers.OpenAICompatible.ChatLanguageModel do
  @moduledoc """
  OpenAI-compatible chat language model implementation.

  This module implements the language model interface for OpenAI-compatible APIs.
  """

  alias AI.Provider.Utils.EventSource

  defstruct [
    :provider,
    :model_id,
    :formatted_provider,
    :supports_image_urls,
    :supports_structured_outputs
  ]

  alias AI.Providers.OpenAICompatible.MessageConversion

  @doc """
  Creates a new OpenAI-compatible chat language model.

  ## Options
    * `:model_id` - The model ID to use (required)
    * `:supports_image_urls` - Whether the model supports image URLs (default: false)
    * `:supports_structured_outputs` - Whether the model supports structured outputs (default: false)
  """
  def new(provider, opts) do
    model_id = Map.fetch!(opts, :model_id)
    supports_image_urls = Map.get(opts, :supports_image_urls, false)
    supports_structured_outputs = Map.get(opts, :supports_structured_outputs, false)

    # Format provider name
    formatted_provider = format_provider_name(provider.name)

    %__MODULE__{
      provider: provider,
      model_id: model_id,
      formatted_provider: formatted_provider,
      supports_image_urls: supports_image_urls,
      supports_structured_outputs: supports_structured_outputs
    }
  end

  @doc """
  Generate text using the OpenAI-compatible API.

  ## Options
    * `:messages` - List of messages to send to the API (required)
    * `:temperature` - Temperature for sampling (default: 1.0)
    * `:max_tokens` - Maximum number of tokens to generate (optional)
    * `:tools` - List of tools available to the model (optional)
    * `:tool_choice` - Tool choice configuration (optional)
    * `:response_format` - Response format configuration (optional)
  """
  def do_generate(model, opts) do
    messages = Map.get(opts, :messages, [])

    # Convert messages to OpenAI-compatible format
    openai_messages = MessageConversion.convert_to_openai_compatible_chat_messages(messages)

    # Build request body
    request_body = %{
      model: model.model_id,
      messages: openai_messages
    }

    # Add optional parameters if provided
    request_body = add_optional_params(request_body, opts)

    # Make API request
    case make_api_request(model.provider, "/v1/chat/completions", request_body) do
      {:ok, response} ->
        # Process API response and return result
        process_response(response)

      {:error, error} ->
        {:error, error}
    end
  end

  # Add optional parameters to the request body
  defp add_optional_params(request_body, opts) do
    request_body
    |> add_param(:temperature, opts)
    |> add_param(:max_tokens, opts)
    |> add_param(:tools, opts)
    |> add_param(:tool_choice, opts)
    |> add_param(:response_format, opts)
  end

  # Helper to add a parameter if it exists in opts
  defp add_param(request_body, key, opts) do
    case Map.get(opts, key) do
      nil -> request_body
      value -> Map.put(request_body, key, value)
    end
  end

  # Make an API request to the OpenAI-compatible API
  defp make_api_request(provider, path, body) do
    url = "#{provider.base_url}#{path}"

    Tesla.client([
      {Tesla.Middleware.Headers, ensure_headers_list(provider.headers)},
      {Tesla.Middleware.JSON, []}
    ])
    |> Tesla.post(url, body)
    |> handle_response()
  end

  # Ensure headers are in the proper format (list of tuples)
  defp ensure_headers_list(headers) when is_list(headers), do: headers

  defp ensure_headers_list(headers) when is_map(headers) do
    Enum.map(headers, fn {key, value} -> {key, value} end)
  end

  defp ensure_headers_list(_), do: []

  # Handle the Tesla response
  defp handle_response({:ok, %Tesla.Env{status: 200, body: body}}) do
    {:ok, body}
  end

  defp handle_response({:ok, %Tesla.Env{status: status, body: body}}) do
    {:error, %{status: status, body: body}}
  end

  defp handle_response({:error, reason}) do
    {:error, reason}
  end

  # Process the API response to extract the relevant information
  defp process_response(response) do
    # Extract the first choice from the response
    first_choice = get_in(response, ["choices", Access.at(0)])

    # Extract the message content from the first choice
    content = get_in(first_choice, ["message", "content"])

    # Extract reasoning content if available
    reasoning = extract_reasoning(first_choice)

    # Extract usage statistics and finish reason
    usage = response["usage"]
    finish_reason = first_choice["finish_reason"]

    # Extract tool calls if present
    tool_calls = extract_tool_calls(first_choice)

    # Build the result
    result = %{
      text: content || "",
      reasoning: reasoning,
      finish_reason: finish_reason || "unknown",
      usage: %{
        prompt_tokens: usage["prompt_tokens"] || 0,
        completion_tokens: usage["completion_tokens"] || 0,
        total_tokens: usage["total_tokens"] || 0
      },
      tool_calls: tool_calls,
      provider_metadata: response
    }

    {:ok, result}
  end

  # Extract tool calls from the response
  defp extract_tool_calls(%{"message" => %{"tool_calls" => tool_calls}})
       when is_list(tool_calls) do
    Enum.map(tool_calls, fn tool_call ->
      %{
        id: tool_call["id"],
        type: tool_call["type"],
        function: %{
          name: get_in(tool_call, ["function", "name"]),
          arguments: process_tool_arguments(get_in(tool_call, ["function", "arguments"]))
        }
      }
    end)
  end

  defp extract_tool_calls(_) do
    []
  end

  # Process tool arguments from string to map
  defp process_tool_arguments(arguments) when is_binary(arguments) do
    case Jason.decode(arguments) do
      {:ok, decoded} -> decoded
      _ -> %{}
    end
  end

  defp process_tool_arguments(_) do
    %{}
  end

  # Extract reasoning content from the response
  defp extract_reasoning(%{
         "message" => %{"reasoning" => [%{"type" => "text", "text" => text} | _rest]}
       }) do
    text
  end

  defp extract_reasoning(_) do
    nil
  end

  # Format provider name to handle dashes, underscores, etc.
  defp format_provider_name(name) when is_binary(name) do
    name
  end

  @doc """
  Stream text generation using the OpenAI-compatible API.

  This function enables streaming responses from the model, returning chunks
  as they are generated rather than waiting for the complete response.

  ## Options
    * `:messages` - List of messages to send to the API (required)
    * `:temperature` - Temperature for sampling (default: 1.0)
    * `:max_tokens` - Maximum number of tokens to generate (optional)
    * `:tools` - List of tools available to the model (optional)
    * `:tool_choice` - Tool choice configuration (optional)
    * `:response_format` - Response format configuration (optional)
  """
  def do_stream(model, opts) do
    messages = Map.get(opts, :messages, [])

    # Convert messages to OpenAI-compatible format
    openai_messages = MessageConversion.convert_to_openai_compatible_chat_messages(messages)

    # Build request body
    request_body = %{
      model: model.model_id,
      messages: openai_messages,
      stream: true
    }

    # Add optional parameters if provided
    request_body = add_optional_params(request_body, opts)

    # Create URL and headers
    url = "#{model.provider.base_url}/v1/chat/completions"
    headers = ensure_headers_map(model.provider.headers)

    # Get the EventSource module to use (allows mocking)
    event_source_module = Application.get_env(:ai_sdk, :event_source_module, EventSource)
    
    # Make streaming API request
    case event_source_module.post(url, request_body, headers, opts) do
      {:ok, response} ->
        stream = process_stream_events(response)
        
        {:ok, %{
          stream: stream,
          warnings: [],
          raw_response: %{
            request_body: request_body,
            url: url
          }
        }}

      {:error, error} ->
        {:error, error}
    end
  end

  # Process streaming events into a unified stream
  defp process_stream_events(response) do
    # Create a stream that processes each SSE event from the EventSource response
    Stream.resource(
      # Initialize with the source stream and initial state
      fn -> {response.stream, %{finished: false, seen_events: 0}} end,
      
      # Process each event from the input stream
      fn
        # If we're at the end, halt
        {_stream, %{finished: true}} -> 
          {:halt, nil}
          
        # Process the source stream
        {stream, acc} ->
          # Try to get the next event
          case Enum.take(stream, 1) do
            # We got an event - process it
            [event | _] ->
              # Count seen events to detect no more events
              updated_acc = %{acc | seen_events: acc.seen_events + 1}
              
              case event do
                # Text delta - pass it through
                {:text_delta, text} ->
                  {[{:text_delta, text}], {stream, updated_acc}}
                  
                # Finish event - emit it and mark as finished
                {:finish, reason} ->
                  {[{:finish, reason}], {stream, %{updated_acc | finished: true}}}
                  
                # Error event - pass through and mark finished
                {:error, error} ->
                  {[{:error, error}], {stream, %{updated_acc | finished: true}}}
                  
                # Tool call - pass it through (for future tool call streaming)
                {:tool_call, tool_call} ->
                  {[{:tool_call, tool_call}], {stream, updated_acc}}
                  
                # Tool call delta - pass it through (for future tool call streaming)
                {:tool_call_delta, id, delta} ->
                  {[{:tool_call_delta, id, delta}], {stream, updated_acc}}
                  
                # Pass through other events as metadata
                other ->
                  {[{:metadata, other}], {stream, updated_acc}}
              end
              
            # Stream is empty, either we're done or need to keep waiting
            [] -> 
              if acc.seen_events > 0 do
                # We've seen events before but now there are none, so we're done
                # Emit a finish event if we haven't already
                {[{:finish, "complete"}], {stream, %{acc | finished: true}}}
              else
                # No events seen yet, keep waiting
                {[], {stream, acc}}
              end
          end
      end,
      
      # Cleanup function - nothing to do here
      fn _ -> :ok end
    )
  end

  # Convert headers to map format for EventSource
  defp ensure_headers_map(headers) when is_list(headers) do
    Enum.into(headers, %{})
  end

  defp ensure_headers_map(headers) when is_map(headers) do
    headers
  end

  defp ensure_headers_map(_) do
    %{}
  end
end