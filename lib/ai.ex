defmodule AI do
  @moduledoc """
  AI is an Elixir SDK for building AI-powered applications.

  It provides a unified API to interact with various AI model providers
  like OpenAI, Anthropic, and others.
  """

  alias AI.Core.GenerateText
  alias AI.Core.StreamText
  alias AI.Providers.OpenAICompatible.Provider
  alias AI.Providers.OpenAICompatible.ChatLanguageModel
  alias AI.Providers.OpenAI.ChatLanguageModel, as: OpenAIChatLanguageModel
  alias AI.Providers.OpenAI.CompletionLanguageModel, as: OpenAICompletionLanguageModel

  @doc """
  Generates text using an AI model.

  ## Options

    * `:model` - The language model to use
    * `:system` - A system message that will be part of the prompt
    * `:prompt` - A simple text prompt (can use either prompt or messages)
    * `:messages` - A list of messages (can use either prompt or messages)
    * `:max_tokens` - Maximum number of tokens to generate
    * `:temperature` - Temperature setting for randomness
    * `:top_p` - Nucleus sampling
    * `:tools` - Tools that are accessible to and can be called by the model
    * `:tool_choice` - The tool choice strategy (default: 'auto')

  ## Examples

      {:ok, result} = AI.generate_text(%{
        model: AI.openai_compatible("gpt-3.5-turbo", base_url: "https://api.example.com"),
        system: "You are a friendly assistant!",
        prompt: "Why is the sky blue?"
      })

      IO.puts(result.text)
  """
  @spec generate_text(map()) :: {:ok, map()} | {:error, any()}
  def generate_text(options) do
    GenerateText.generate_text(options)
  end

  @doc """
  Streams text generation from an AI model, returning chunks as they are generated.

  ## Options

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

  ## Examples

      {:ok, result} = AI.stream_text(%{
        model: AI.openai_compatible("gpt-3.5-turbo", base_url: "https://api.example.com"),
        system: "You are a friendly assistant!",
        prompt: "Why is the sky blue?"
      })

      # Process chunks as they arrive
      result.stream
      |> Stream.each(fn
        {:text_delta, chunk} -> IO.write(chunk)
        _ -> :ok
      end)
      |> Stream.run()
  """
  @spec stream_text(map()) :: {:ok, map()} | {:error, any()}
  def stream_text(options) do
    StreamText.stream_text(options)
  end

  @doc """
  Creates an OpenAI-compatible provider with the specified model ID.

  This function creates a model that can be used with OpenAI-compatible APIs,
  such as Ollama, LMStudio, and any other API that follows the OpenAI format.

  ## Options
    * `:base_url` - The base URL of the API (required)
    * `:api_key` - The API key to use for authentication (optional)
    * `:headers` - Additional headers to include in requests (optional)
    * `:supports_image_urls` - Whether the model supports image URLs (default: false)
    * `:supports_structured_outputs` - Whether the model supports structured outputs (default: false)

  ## Examples

      model = AI.openai_compatible("gpt-3.5-turbo", base_url: "https://api.example.com")
      
      # With API key
      model = AI.openai_compatible("gpt-4", 
        base_url: "https://api.openai.com", 
        api_key: System.get_env("OPENAI_API_KEY")
      )
  """
  @spec openai_compatible(String.t(), keyword() | map()) :: struct()
  def openai_compatible(model_id, opts \\ %{}) do
    # Convert keyword list to map if needed
    opts = if Keyword.keyword?(opts), do: Map.new(opts), else: opts

    # Create the provider
    provider = Provider.new(opts)

    # Create the chat language model
    ChatLanguageModel.new(provider, Map.put(opts, :model_id, model_id))
  end

  @doc """
  Creates an OpenAI model with the specified model ID.

  This function creates a model that uses the official OpenAI API.

  ## Options
    * `:api_key` - The API key to use for authentication (default: OPENAI_API_KEY environment variable)
    * `:base_url` - The base URL of the API (default: "https://api.openai.com")
    * `:structured_outputs` - Whether the model supports structured outputs (default: false)
    * `:use_legacy_function_calling` - Whether to use legacy function calling format (default: false)
    * `:reasoning_effort` - For O-series models (o1, o3), controls the reasoning effort (low, medium, high)

  ## Examples

      model = AI.openai("gpt-4")
      
      # With custom API key
      model = AI.openai("gpt-4", api_key: "your-api-key")
      
      # With structured outputs
      model = AI.openai("gpt-4", structured_outputs: true)
      
      # With reasoning effort for O-series models
      model = AI.openai("o1-mini", reasoning_effort: "high")
  """
  @spec openai(String.t(), keyword() | map()) :: struct()
  def openai(model_id, opts \\ %{}) do
    # Convert keyword list to map if needed
    opts = if Keyword.keyword?(opts), do: Map.new(opts), else: opts

    # Get API key from options or environment variable
    api_key = Map.get(opts, :api_key) || System.get_env("OPENAI_API_KEY")

    # Get base URL from options or use default
    base_url = Map.get(opts, :base_url, "https://api.openai.com")

    # Extract settings from options
    settings =
      Map.take(opts, [:structured_outputs, :use_legacy_function_calling, :reasoning_effort])

    # Configure headers function
    headers_fn = fn ->
      %{
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => "application/json"
      }
    end

    # Configure URL function
    url_fn = fn %{path: path} ->
      "#{String.trim_trailing(base_url, "/")}/v1#{path}"
    end

    # Create the config
    config = %{
      provider: "openai",
      headers: headers_fn,
      url: url_fn
    }

    # Create the OpenAI chat language model
    OpenAIChatLanguageModel.new(model_id, settings, config)
  end

  @doc """
  Creates an OpenAI completion model with the specified model ID.

  This function creates a model that uses the official OpenAI completion API.

  ## Options
    * `:api_key` - The API key to use for authentication (default: OPENAI_API_KEY environment variable)
    * `:base_url` - The base URL of the API (default: "https://api.openai.com")

  ## Examples

      model = AI.openai_completion("text-davinci-003")
      
      # With custom API key
      model = AI.openai_completion("text-davinci-003", api_key: "your-api-key")
  """
  @spec openai_completion(String.t(), keyword() | map()) :: struct()
  def openai_completion(model_id, opts \\ %{}) do
    # Convert keyword list to map if needed
    opts = if Keyword.keyword?(opts), do: Map.new(opts), else: opts

    # Get API key from options or environment variable
    api_key = Map.get(opts, :api_key) || System.get_env("OPENAI_API_KEY")

    # Get base URL from options or use default
    base_url = Map.get(opts, :base_url, "https://api.openai.com")

    # Extract settings from options
    settings = Map.take(opts, [])

    # Configure headers function
    headers_fn = fn ->
      %{
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => "application/json"
      }
    end

    # Configure URL function
    url_fn = fn %{path: path} ->
      "#{String.trim_trailing(base_url, "/")}/v1#{path}"
    end

    # Create the config
    config = %{
      provider: "openai",
      headers: headers_fn,
      url: url_fn
    }

    # Create the OpenAI completion language model
    OpenAICompletionLanguageModel.new(model_id, settings, config)
  end
end
