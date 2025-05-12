defmodule AI.Stream.Event do
  @moduledoc """
  Defines standard event types for streaming interactions with AI models.

  These structured event types represent different kinds of data that can be
  emitted during a streaming interaction, allowing for standardized handling
  across different providers.
  """

  defmodule TextDelta do
    @moduledoc """
    Represents a chunk of text from the model.
    """

    @enforce_keys [:content]
    defstruct [:content]

    @type t :: %__MODULE__{
            content: String.t()
          }
  end

  defmodule ToolCall do
    @moduledoc """
    Represents a tool call from the model.
    """

    @enforce_keys [:id, :name, :arguments]
    defstruct [:id, :name, :arguments]

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            arguments: String.t()
          }
  end

  defmodule Finish do
    @moduledoc """
    Represents the completion of a stream with a reason.
    """

    @enforce_keys [:reason]
    defstruct [:reason]

    @type t :: %__MODULE__{
            reason: String.t()
          }
  end

  defmodule Metadata do
    @moduledoc """
    Represents metadata information from the model.
    """

    @enforce_keys [:data]
    defstruct [:data]

    @type t :: %__MODULE__{
            data: map()
          }
  end

  defmodule Error do
    @moduledoc """
    Represents an error that occurred during streaming.
    """

    @enforce_keys [:error]
    defstruct [:error]

    @type t :: %__MODULE__{
            error: any()
          }
  end

  # Define type aliases for better readability
  @type t :: TextDelta.t() | ToolCall.t() | Finish.t() | Metadata.t() | Error.t()
  @type tuple_format ::
          {:text_delta, String.t()}
          | {:tool_call, map()}
          | {:finish, String.t()}
          | {:metadata, map()}
          | {:error, any()}

  @doc """
  Converts an Event struct to a tuple format.

  ## Examples

      iex> event = %AI.Stream.Event.TextDelta{content: "Hello"}
      iex> AI.Stream.Event.to_tuple(event)
      {:text_delta, "Hello"}
  """
  @spec to_tuple(t()) :: tuple_format()
  def to_tuple(%TextDelta{content: content}), do: {:text_delta, content}

  def to_tuple(%ToolCall{id: id, name: name, arguments: arguments}),
    do: {:tool_call, %{id: id, name: name, arguments: arguments}}

  def to_tuple(%Finish{reason: reason}), do: {:finish, reason}
  def to_tuple(%Metadata{data: data}), do: {:metadata, data}
  def to_tuple(%Error{error: error}), do: {:error, error}

  @doc """
  Converts a tuple format to an Event struct.

  ## Examples

      iex> AI.Stream.Event.from_tuple({:text_delta, "Hello"})
      %AI.Stream.Event.TextDelta{content: "Hello"}
  """
  @spec from_tuple(tuple_format()) :: t()
  def from_tuple({:text_delta, content}), do: %TextDelta{content: content}

  def from_tuple({:tool_call, %{id: id, name: name, arguments: arguments}}),
    do: %ToolCall{id: id, name: name, arguments: arguments}

  def from_tuple({:finish, reason}), do: %Finish{reason: reason}
  def from_tuple({:metadata, data}), do: %Metadata{data: data}
  def from_tuple({:error, error}), do: %Error{error: error}
end
