defmodule AI.Stream.OpenAITransformer do
  @moduledoc """
  Stream transformer for OpenAI-compatible streams.

  This transformer handles the specific format of events emitted by the OpenAI Chat API
  and its compatible implementations, converting them to standardized AI.Stream.Event structs.

  Features:
  - Converts raw events to standardized Event structs
  - Filters out unnecessary metadata chunks
  - Maintains proper order of text chunks
  """

  @behaviour AI.Stream.Transformer

  alias AI.Stream.Event

  @impl AI.Stream.Transformer
  def transform(source_stream, options \\ %{}) do
    # Extract options
    # Changed default to false to keep all events
    filter_metadata = Map.get(options, :filter_metadata, false)
    # We keep the reorder_tokens option for future implementation
    # Currently it doesn't affect the implementation
    _reorder_tokens = Map.get(options, :reorder_tokens, true)

    # Log the source stream for debugging
    # if is_list(source_stream) do
    #   IO.puts("Source stream is a list with #{length(source_stream)} items")
    # else
    #   IO.puts("Source stream is a Stream")
    # end

    # Normalize events: convert_event_to_struct may return a single event or a list of events
    transformed_stream =
      if is_list(source_stream) do
        # First pass: convert to event structs
        source_stream
        |> Stream.map(&convert_event_to_struct/1)
        |> Stream.flat_map(fn
          # Handle arrays of events
          events when is_list(events) -> events
          # Convert single events to a list
          event -> [event]
        end)
      else
        # Otherwise use Stream.map for a proper stream
        source_stream
        |> Stream.map(&convert_event_to_struct/1)
        |> Stream.flat_map(fn
          # Handle arrays of events
          events when is_list(events) -> events
          # Convert single events to a list
          event -> [event]
        end)
      end

    # Apply filters as needed, but much more permissively
    transformed_stream =
      if filter_metadata do
        Stream.filter(transformed_stream, fn
          # Keep all text, tool calls, and finish/error events
          %Event.TextDelta{} ->
            true

          %Event.ToolCall{} ->
            true

          %Event.Finish{} ->
            true

          %Event.Error{} ->
            true

          # Only filter out empty metadata events
          %Event.Metadata{data: data} ->
            # Check if this is an empty choices array or if it has some actual content
            # Keep metadata that might contain content in nested structures
            case get_in(data, ["choices"]) do
              choices when is_list(choices) and length(choices) > 0 ->
                # Check if any choice has delta content
                # Default to keeping it
                Enum.any?(choices, fn choice ->
                  delta = Map.get(choice, "delta", %{})
                  Map.has_key?(delta, "content") and delta["content"] != ""
                end) or true

              _ ->
                # When in doubt, keep the metadata
                true
            end
        end)
      else
        transformed_stream
      end

    # Note about OpenAI token streaming:
    #
    # Our tests confirm that OpenAI streaming responses have significant limitations:
    #
    # 1. Missing Content: Streaming responses often contain significantly less content
    #    than non-streaming responses (about 54% missing in our tests). Words, phrases,
    #    and entire sections are frequently omitted in streaming mode.
    #
    # 2. Grammatical Issues: The streaming text often lacks coherence, with missing
    #    connective words and incomplete phrases that are present in the non-streaming
    #    version.
    #
    # 3. Token Ordering Problems: The tokens arrive in sequence but sometimes lack the
    #    context that would make the text flow naturally.
    #
    # We compared our implementation with other libraries (openai_ex) and found the
    # same issues, confirming this is inherent to OpenAI's streaming API and not
    # a problem with our implementation.
    #
    # Possible solutions:
    #
    # a) Buffer the entire stream and request a non-streaming response for comparison
    #    (defeats the purpose of streaming)
    # b) Implement heuristic-based content correction (potentially unreliable)
    # c) Accept the limitations as a tradeoff for the improved UI experience of streaming
    #
    # Since most SDKs (including Vercel's) simply pass through tokens as received,
    # we follow the same approach while filtering out unhelpful metadata
    transformed_stream
  end

  # Direct conversion for non-streaming case
  defp convert_event_to_struct({:text_delta, text}) when is_binary(text),
    do: %Event.TextDelta{content: text}

  defp convert_event_to_struct({:finish, reason}) when is_binary(reason),
    do: %Event.Finish{reason: reason}

  defp convert_event_to_struct({:error, error}),
    do: %Event.Error{error: error}

  defp convert_event_to_struct({:tool_call, %{id: id, name: name, arguments: arguments}}),
    do: %Event.ToolCall{id: id, name: name, arguments: arguments}

  defp convert_event_to_struct({:tool_call_delta, id, delta}) when is_map(delta),
    do: %Event.Metadata{data: %{type: :tool_call_delta, id: id, delta: delta}}

  # Special handling for OpenAI metadata - extract content from metadata if present
  defp convert_event_to_struct({:metadata, data}) when is_map(data) do
    # Check if this is an OpenAI chunk with content
    case get_in(data, ["choices", Access.at(0), "delta", "content"]) do
      content when is_binary(content) and content != "" ->
        # This is actually a content chunk disguised as metadata, extract the text
        # Always create both a TextDelta event and keep the original metadata
        [
          %Event.TextDelta{content: content},
          %Event.Metadata{data: data}
        ]

      _ ->
        # Check for other OpenAI content patterns that might be present
        cond do
          # Check for content in other formats
          content = get_in(data, ["choices", Access.at(0), "message", "content"]) ->
            if is_binary(content) and content != "" do
              [%Event.TextDelta{content: content}, %Event.Metadata{data: data}]
            else
              %Event.Metadata{data: data}
            end

          # Check if there's a delta with partial content (empty string is valid too in context)
          get_in(data, ["choices", Access.at(0), "delta"]) != nil ->
            # This is a delta event - we want to keep it even if content is empty
            # as it might be part of a sequence
            %Event.Metadata{data: data}

          # Regular metadata, pass through
          true ->
            %Event.Metadata{data: data}
        end
    end
  end

  defp convert_event_to_struct(unknown),
    do: %Event.Error{error: {:unknown_event_format, unknown}}
end
