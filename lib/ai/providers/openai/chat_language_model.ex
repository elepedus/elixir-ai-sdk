defmodule AI.Providers.OpenAI.ChatLanguageModel do
  @moduledoc """
  Implementation of the OpenAI chat language model.
  """

  alias AI.Providers.OpenAI.ChatMessages
  alias AI.Provider.{LanguageModelV1, UnsupportedFunctionalityError}
  alias AI.Provider.Utils.{Headers, JsonApi, EventSource}

  @behaviour LanguageModelV1

  @type t :: %__MODULE__{
          model_id: String.t(),
          settings: map(),
          config: map()
        }

  defstruct [:model_id, :settings, :config]

  @reasoning_models %{
    "o1-mini" => %{system_message_mode: :remove},
    "o1-mini-2024-09-12" => %{system_message_mode: :remove},
    "o1-preview" => %{system_message_mode: :remove},
    "o1-preview-2024-09-12" => %{system_message_mode: :remove},
    "o3" => %{system_message_mode: :developer},
    "o3-2025-04-16" => %{system_message_mode: :developer},
    "o3-mini" => %{system_message_mode: :developer},
    "o3-mini-2025-01-31" => %{system_message_mode: :developer},
    "o4-mini" => %{system_message_mode: :developer},
    "o4-mini-2025-04-16" => %{system_message_mode: :developer}
  }

  @impl LanguageModelV1
  def specification_version, do: "v1"

  @doc """
  Creates a new OpenAI chat language model instance.
  """
  def new(model_id, settings, config) do
    %__MODULE__{
      model_id: model_id,
      settings: settings,
      config: config
    }
  end

  @impl LanguageModelV1
  def supports_structured_outputs?(%__MODULE__{} = model) do
    Map.get(model.settings, :structured_outputs) || is_reasoning_model?(model.model_id)
  end

  @impl LanguageModelV1
  def default_object_generation_mode(%__MODULE__{} = model) do
    if is_audio_model?(model.model_id) do
      :tool
    else
      if supports_structured_outputs?(model), do: :json, else: :tool
    end
  end

  @impl LanguageModelV1
  def provider(%__MODULE__{config: config}), do: config.provider

  @impl LanguageModelV1
  def supports_image_urls?(%__MODULE__{settings: settings}) do
    !Map.get(settings, :download_images, false)
  end

  @impl LanguageModelV1
  def do_generate(%__MODULE__{} = model, options) do
    # Convert input options to the format expected by this module
    adapted_options = convert_options(options)

    {body, warnings} = get_args(model, adapted_options)

    url = get_url(model, "/chat/completions")
    headers = get_headers(model, adapted_options)

    case JsonApi.post(url, body, headers, adapted_options) do
      {:ok, response} ->
        handle_generate_response(response, body, warnings)

      {:error, error} ->
        {:error, error}
    end
  end

  # Convert options from the general format used by AI.generate_text
  # to the specific format expected by this module's get_args function
  defp convert_options(options) do
    # Convert messages to the format expected by ChatMessages.convert_to_openai_chat_messages
    prompt =
      case Map.get(options, :messages) do
        nil ->
          []

        messages ->
          Enum.map(messages, fn message ->
            case message.role do
              "system" ->
                {:system, message.content}

              "user" ->
                {:user, [%{type: :text, text: message.content}]}

              "assistant" ->
                {:assistant, [%{type: :text, text: message.content}]}

              "tool" ->
                {:tool,
                 [
                   %{
                     type: :tool_result,
                     tool_call_id: "default",
                     tool_name: "default",
                     result: message.content
                   }
                 ]}

              _ ->
                raise "Unsupported message role: #{message.role}"
            end
          end)
      end

    # Return the adapted options in the format expected by get_args
    %{
      mode: %{type: :regular},
      prompt: prompt,
      max_tokens: Map.get(options, :max_tokens, 1024),
      temperature: Map.get(options, :temperature, 0.7),
      top_p: Map.get(options, :top_p, 1.0),
      top_k: Map.get(options, :top_k),
      frequency_penalty: Map.get(options, :frequency_penalty, 0.0),
      presence_penalty: Map.get(options, :presence_penalty, 0.0),
      stop_sequences: Map.get(options, :stop_sequences),
      response_format: Map.get(options, :response_format),
      seed: Map.get(options, :seed),
      provider_metadata: Map.get(options, :provider_metadata, %{})
    }
  end

  @impl LanguageModelV1
  def do_stream(%__MODULE__{} = model, options) do
    # Convert options for consistency with do_generate
    adapted_options = convert_options(options)

    {body, warnings} = get_args(model, adapted_options)
    body = Map.put(body, :stream, true)

    url = get_url(model, "/chat/completions")
    headers = get_headers(model, adapted_options)

    # Get the EventSource module from application config, fallback to real module
    event_source_module = Application.get_env(:ai_sdk, :event_source_module, EventSource)

    case event_source_module.post(url, body, headers, adapted_options) do
      {:ok, response} ->
        handle_stream_response(response, body, warnings, model.settings)

      {:error, error} ->
        {:error, error}
    end
  end

  # Private functions

  defp get_args(model, %{
         mode: mode,
         prompt: prompt,
         max_tokens: max_tokens,
         temperature: temperature,
         top_p: top_p,
         top_k: top_k,
         frequency_penalty: frequency_penalty,
         presence_penalty: presence_penalty,
         stop_sequences: stop_sequences,
         response_format: response_format,
         seed: seed,
         provider_metadata: provider_metadata
       }) do
    warnings = []

    warnings =
      if top_k != nil,
        do: [%{type: :unsupported_setting, setting: :top_k} | warnings],
        else: warnings

    use_legacy_function_calling = Map.get(model.settings, :use_legacy_function_calling, false)

    if use_legacy_function_calling && Map.get(model.settings, :parallel_tool_calls, false) do
      raise UnsupportedFunctionalityError, "useLegacyFunctionCalling with parallelToolCalls"
    end

    if use_legacy_function_calling && supports_structured_outputs?(model) do
      raise UnsupportedFunctionalityError, "structuredOutputs with useLegacyFunctionCalling"
    end

    chat_messages =
      ChatMessages.convert_to_openai_chat_messages(
        prompt,
        use_legacy_function_calling: use_legacy_function_calling,
        system_message_mode: get_system_message_mode(model.model_id)
      )

    warnings = warnings ++ chat_messages.warnings

    # Build the base arguments map but omit null values
    base_args_with_nulls = %{
      model: model.model_id,
      logit_bias: get_in(model.settings, [:logit_bias]),
      logprobs: get_logprobs_setting(model.settings),
      top_logprobs: get_top_logprobs_setting(model.settings),
      user: get_in(model.settings, [:user]),
      parallel_tool_calls: get_in(model.settings, [:parallel_tool_calls]),
      max_tokens: max_tokens,
      temperature: temperature,
      top_p: top_p,
      frequency_penalty: frequency_penalty,
      presence_penalty: presence_penalty,
      stop: stop_sequences,
      seed: seed,
      messages: chat_messages.messages
    }

    # Remove nil values to avoid API errors
    base_args = Map.reject(base_args_with_nulls, fn {_k, v} -> v == nil end)

    base_args = maybe_add_response_format(base_args, response_format, model)
    base_args = maybe_add_openai_specific_settings(base_args, provider_metadata)
    {base_args, warnings} = maybe_adjust_reasoning_model_settings(base_args, model, warnings)

    args =
      case mode.type do
        :regular ->
          {tools, tool_warnings} =
            prepare_tools(mode, use_legacy_function_calling, supports_structured_outputs?(model))

          {args, warnings} = {Map.merge(base_args, tools), warnings ++ tool_warnings}
          {args, warnings}

        :object_json ->
          response_format =
            if supports_structured_outputs?(model) && mode.schema != nil do
              %{
                type: "json_schema",
                json_schema: %{
                  schema: mode.schema,
                  strict: true,
                  name: mode.name || "response",
                  description: mode.description
                }
              }
            else
              %{type: "json_object"}
            end

          {Map.put(base_args, :response_format, response_format), warnings}

        :object_tool ->
          if use_legacy_function_calling do
            {Map.merge(base_args, %{
               function_call: %{name: mode.tool.name},
               functions: [
                 %{
                   name: mode.tool.name,
                   description: mode.tool.description,
                   parameters: mode.tool.parameters
                 }
               ]
             }), warnings}
          else
            {Map.merge(base_args, %{
               tool_choice: %{
                 type: "function",
                 function: %{name: mode.tool.name}
               },
               tools: [
                 %{
                   type: "function",
                   function: %{
                     name: mode.tool.name,
                     description: mode.tool.description,
                     parameters: mode.tool.parameters,
                     strict: if(supports_structured_outputs?(model), do: true, else: nil)
                   }
                 }
               ]
             }), warnings}
          end
      end

    args
  end

  defp get_url(%__MODULE__{config: config, model_id: model_id}, path) do
    config.url.(%{model_id: model_id, path: path})
  end

  defp get_headers(%__MODULE__{config: config}, options) do
    Headers.combine(config.headers.(), Map.get(options, :headers, %{}))
  end

  defp get_logprobs_setting(settings) do
    case settings do
      %{logprobs: true} -> true
      %{logprobs: n} when is_integer(n) -> true
      _ -> nil
    end
  end

  defp get_top_logprobs_setting(settings) do
    case settings do
      %{logprobs: n} when is_integer(n) -> n
      %{logprobs: true} -> 0
      _ -> nil
    end
  end

  defp maybe_add_response_format(args, response_format, model) do
    case response_format do
      %{type: "json"} = format ->
        if supports_structured_outputs?(model) && format.schema != nil do
          Map.put(args, :response_format, %{
            type: "json_schema",
            json_schema: %{
              schema: format.schema,
              strict: true,
              name: format.name || "response",
              description: format.description
            }
          })
        else
          Map.put(args, :response_format, %{type: "json_object"})
        end

      _ ->
        args
    end
  end

  defp maybe_add_openai_specific_settings(args, metadata) do
    openai_metadata = get_in(metadata, [:openai]) || %{}

    args
    |> maybe_put(:max_completion_tokens, openai_metadata[:max_completion_tokens])
    |> maybe_put(:store, openai_metadata[:store])
    |> maybe_put(:metadata, openai_metadata[:metadata])
    |> maybe_put(:prediction, openai_metadata[:prediction])
    |> maybe_put(:reasoning_effort, openai_metadata[:reasoning_effort])
  end

  defp maybe_adjust_reasoning_model_settings(args, model, warnings) do
    cond do
      is_reasoning_model?(model.model_id) ->
        # For reasoning models (o1, o3, etc.), certain parameters are not supported
        # We add warnings for these parameters but still send the cleaned request
        warnings = add_unsupported_setting_warnings(warnings, args)

        # We need to drop these parameters from the args to avoid API errors
        cleaned_args =
          args
          |> Map.drop([
            :temperature,
            :top_p,
            :frequency_penalty,
            :presence_penalty,
            :logit_bias,
            :logprobs,
            :top_logprobs
          ])
          |> maybe_adjust_max_tokens()

        # Add reasoning_effort if it's in the provider_metadata
        cleaned_args =
          case get_in(model.settings, [:reasoning_effort]) do
            nil -> cleaned_args
            effort -> Map.put(cleaned_args, :reasoning_effort, effort)
          end

        {cleaned_args, warnings}

      String.starts_with?(model.model_id, "gpt-4o-search-preview") ||
          String.starts_with?(model.model_id, "gpt-4o-mini-search-preview") ->
        if args[:temperature] != nil do
          {Map.delete(args, :temperature),
           [
             %{
               type: :unsupported_setting,
               setting: :temperature,
               details:
                 "temperature is not supported for the search preview models and has been removed."
             }
             | warnings
           ]}
        else
          {args, warnings}
        end

      true ->
        {args, warnings}
    end
  end

  # Helper to add a value to a map only if the value is not nil
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp add_unsupported_setting_warnings(warnings, args) do
    warnings
    |> maybe_add_warning(
      args[:temperature],
      :temperature,
      "temperature is not supported for reasoning models"
    )
    |> maybe_add_warning(args[:top_p], :top_p, "topP is not supported for reasoning models")
    |> maybe_add_warning(
      args[:frequency_penalty],
      :frequency_penalty,
      "frequencyPenalty is not supported for reasoning models"
    )
    |> maybe_add_warning(
      args[:presence_penalty],
      :presence_penalty,
      "presencePenalty is not supported for reasoning models"
    )
    |> maybe_add_warning(
      args[:logit_bias],
      :other,
      "logitBias is not supported for reasoning models"
    )
    |> maybe_add_warning(
      args[:logprobs],
      :other,
      "logprobs is not supported for reasoning models"
    )
    |> maybe_add_warning(
      args[:top_logprobs],
      :other,
      "topLogprobs is not supported for reasoning models"
    )
  end

  defp maybe_add_warning(warnings, nil, _setting, _message), do: warnings

  defp maybe_add_warning(warnings, _value, setting, message) do
    [%{type: :unsupported_setting, setting: setting, message: message} | warnings]
  end

  defp maybe_adjust_max_tokens(%{max_tokens: tokens} = args) when not is_nil(tokens) do
    args
    |> Map.put(:max_completion_tokens, tokens)
    |> Map.delete(:max_tokens)
  end

  defp maybe_adjust_max_tokens(args), do: args

  defp is_reasoning_model?(model_id) do
    String.starts_with?(model_id, "o")
  end

  defp is_audio_model?(model_id) do
    String.starts_with?(model_id, "gpt-4o-audio-preview")
  end

  defp get_system_message_mode(model_id) do
    if not is_reasoning_model?(model_id) do
      :system
    else
      get_in(@reasoning_models, [model_id, :system_message_mode]) || :developer
    end
  end

  defp prepare_tools(_mode, _use_legacy_function_calling, _supports_structured_outputs) do
    # TODO: Implement tool preparation
    {%{}, []}
  end

  defp handle_generate_response(response, body, warnings) do
    # Extract the first choice from the response
    first_choice = get_in(response, ["choices", Access.at(0)])

    # Extract the message content
    content = get_in(first_choice, ["message", "content"])

    # Extract finish reason
    finish_reason = get_in(first_choice, ["finish_reason"])

    # Extract usage statistics
    usage = %{
      prompt_tokens: get_in(response, ["usage", "prompt_tokens"]) || 0,
      completion_tokens: get_in(response, ["usage", "completion_tokens"]) || 0,
      total_tokens: get_in(response, ["usage", "total_tokens"]) || 0
    }

    # Create the result
    {:ok,
     %{
       text: content || "",
       finish_reason: finish_reason || "stop",
       usage: usage,
       raw_call: body,
       warnings: warnings
     }}
  end

  def handle_stream_response(response, body, warnings, _settings) do
    # Use the OpenAI transformer to convert the raw stream to standardized events
    alias AI.Stream.OpenAITransformer
    alias AI.Stream.Event

    # Transform the response stream using our dedicated transformer
    transformed_stream = OpenAITransformer.transform(response.stream)

    # Convert the transformed stream (now containing Event structs) back to tuple format
    # This maintains compatibility with the current API while we refactor
    final_stream = Stream.map(transformed_stream, &Event.to_tuple/1)

    {:ok, %{stream: final_stream, raw_call: body, warnings: warnings}}
  end
end
