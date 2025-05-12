defmodule AI.Error do
  @moduledoc """
  Standard error structure for AI module operations.

  This module provides consistent error handling across the AI SDK
  with helpful error messages and context.
  """

  @type t :: %__MODULE__{
          message: String.t(),
          reason: term() | nil,
          source: module() | nil
        }

  defexception [:message, :reason, :source]

  @doc """
  Creates a new error with the given message.

  ## Parameters
    * `message` - A string describing the error
    
  ## Returns
    * `%AI.Error{}` - A new error struct
  """
  @spec new(String.t()) :: t()
  def new(message) when is_binary(message) do
    %__MODULE__{
      message: message,
      reason: nil,
      source: nil
    }
  end

  @doc """
  Creates a new error with the given message and reason.

  ## Parameters
    * `message` - A string describing the error
    * `reason` - The underlying reason or error detail
    
  ## Returns
    * `%AI.Error{}` - A new error struct with reason
  """
  @spec new(String.t(), term()) :: t()
  def new(message, reason) when is_binary(message) do
    %__MODULE__{
      message: message,
      reason: reason,
      source: nil
    }
  end

  @doc """
  Creates a new error with the given message, reason, and source module.

  ## Parameters
    * `message` - A string describing the error
    * `reason` - The underlying reason or error detail
    * `source` - The module that originated the error
    
  ## Returns
    * `%AI.Error{}` - A new error struct with reason and source
  """
  @spec new(String.t(), term(), module()) :: t()
  def new(message, reason, source) when is_binary(message) and is_atom(source) do
    %__MODULE__{
      message: message,
      reason: reason,
      source: source
    }
  end

  @doc """
  Wraps an existing error in an AI.Error with additional context.

  This is useful for adding context to lower-level errors while preserving
  the original error information.

  ## Parameters
    * `original_error` - The original error or exception
    * `message` - A string describing the context of the error
    * `source` - The module wrapping the error
    
  ## Returns
    * `%AI.Error{}` - A new error struct wrapping the original error
  """
  @spec wrap(Exception.t(), String.t(), module()) :: t()
  def wrap(original_error, message, source) when is_binary(message) and is_atom(source) do
    %__MODULE__{
      message: message,
      reason: original_error,
      source: source
    }
  end

  @doc """
  Converts a standard exception to an AI.Error.

  This is useful for standardizing error handling by converting
  various exception types to our common error format.

  ## Parameters
    * `exception` - The exception to convert
    * `source` - The module that caught the exception
    
  ## Returns
    * `%AI.Error{}` - A new error struct
  """
  @spec from_exception(Exception.t(), module()) :: t()
  def from_exception(exception, source) when is_atom(source) do
    %__MODULE__{
      message: Exception.message(exception),
      reason: exception,
      source: source
    }
  end
end
