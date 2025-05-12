defmodule AI.Stream.Transformer do
  @moduledoc """
  Behaviour for stream transformers that convert provider-specific streams to standardized events.

  Stream transformers are responsible for:
  1. Taking provider-specific streaming events
  2. Converting them into standardized AI.Stream.Event structs
  3. Handling provider-specific event formats and quirks

  This separation of concerns allows provider modules to focus on API communication
  while stream transformers handle the interpretation of streaming data formats.
  """

  alias AI.Stream.Event

  @doc """
  Transforms a provider-specific event stream into a stream of standardized events.

  Takes a source stream and any provider-specific options, and returns a new stream
  that emits standardized AI.Stream.Event structs.

  ## Parameters
    * `source_stream` - The original stream from the provider API
    * `options` - Additional options specific to this transformer (if any)
    
  ## Returns
    * A Stream that emits AI.Stream.Event structs
  """
  @callback transform(source_stream :: Stream.t(), options :: map()) :: Stream.t()

  @doc """
  Utility function to convert basic tuple event formats to AI.Stream.Event structs.

  This helper can be used by transformer implementations to simplify conversion
  of simple event tuples to Event structs.

  ## Parameters
    * `tuple_event` - An event in tuple format (e.g., {:text_delta, content})
    
  ## Returns
    * A corresponding AI.Stream.Event struct
  """
  @spec convert_tuple_to_event(tuple()) :: Event.t()
  def convert_tuple_to_event({:text_delta, content}) when is_binary(content),
    do: %Event.TextDelta{content: content}

  def convert_tuple_to_event({:tool_call, %{id: id, name: name, arguments: arguments}}),
    do: %Event.ToolCall{id: id, name: name, arguments: arguments}

  def convert_tuple_to_event({:finish, reason}) when is_binary(reason),
    do: %Event.Finish{reason: reason}

  def convert_tuple_to_event({:metadata, data}) when is_map(data),
    do: %Event.Metadata{data: data}

  def convert_tuple_to_event({:error, error}),
    do: %Event.Error{error: error}

  # Fall through case - unknown event type gets converted to error
  def convert_tuple_to_event(other),
    do: %Event.Error{error: {:unsupported_event_format, other}}
end
