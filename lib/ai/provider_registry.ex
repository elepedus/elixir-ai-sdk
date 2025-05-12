defmodule AI.ProviderRegistry do
  @moduledoc """
  A registry for AI providers and their language models.

  This module provides a central registry for managing different AI providers
  and their associated language models, enabling dynamic registration and lookup.
  """
  use GenServer

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a provider module with the given ID.

  ## Parameters
    * `provider_id` - A string ID for the provider
    * `provider_module` - The module that implements the provider
    * `opts` - Optional configuration for the provider

  ## Returns
    * `:ok` - If registration was successful
    * `{:error, reason}` - If registration failed
  """
  def register(provider_id, provider_module, opts \\ []) do
    GenServer.call(__MODULE__, {:register, provider_id, provider_module, opts})
  end

  @doc """
  Retrieves a provider by its ID.

  ## Parameters
    * `provider_id` - The string ID of the provider to get

  ## Returns
    * `{:ok, provider}` - The provider with its module and options
    * `{:error, :not_found}` - If no provider with that ID is registered
  """
  def get_provider(provider_id) do
    GenServer.call(__MODULE__, {:get_provider, provider_id})
  end

  @doc """
  Gets a language model by its model ID string.

  Model IDs can be in the format "provider:model" to specify which provider should
  handle the model, e.g., "openai:gpt-4" or "anthropic:claude-3-sonnet".

  ## Parameters
    * `model_id` - A string identifying the model, in format "provider:model_name"
    * `opts` - Optional configuration for the model

  ## Returns
    * `{:ok, language_model}` - The initialized language model
    * `{:error, reason}` - If the model or provider could not be found
  """
  def get_language_model(model_id, opts \\ []) when is_binary(model_id) do
    GenServer.call(__MODULE__, {:get_language_model, model_id, opts})
  end

  # Server callbacks
  @impl true
  def init(_opts) do
    {:ok, %{providers: %{}}}
  end

  @impl true
  def handle_call({:register, id, module, opts}, _from, state) do
    updated_providers = Map.put(state.providers, id, %{module: module, opts: opts})
    {:reply, :ok, %{state | providers: updated_providers}}
  end

  @impl true
  def handle_call({:get_provider, id}, _from, state) do
    case Map.get(state.providers, id) do
      nil -> {:reply, {:error, :not_found}, state}
      provider -> {:reply, {:ok, provider}, state}
    end
  end

  @impl true
  def handle_call({:get_language_model, model_id, opts}, _from, state) do
    case parse_model_id(model_id) do
      {:ok, provider_id, model_name} ->
        # Try to get the provider
        case Map.get(state.providers, provider_id) do
          nil ->
            {:reply, {:error, {:provider_not_found, provider_id}}, state}

          %{module: module, opts: provider_opts} ->
            # Get model-specific defaults from provider options
            merged_opts = Keyword.merge(provider_opts, opts)
            # Call the provider's get_language_model function
            result = module.get_language_model(model_name, merged_opts)
            {:reply, result, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Parse a model ID string into provider ID and model name
  defp parse_model_id(model_id) do
    case String.split(model_id, ":", parts: 2) do
      [provider_id, model_name] ->
        {:ok, provider_id, model_name}

      [_] ->
        {:error, {:invalid_model_id, "Model ID must be in format provider:model_name"}}
    end
  end
end
