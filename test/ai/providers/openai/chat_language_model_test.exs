defmodule AI.Providers.OpenAI.ChatLanguageModelTest do
  use ExUnit.Case, async: true
  import Mox

  alias AI.Providers.OpenAI.ChatLanguageModel

  # Ensure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "model creation and configuration" do
    setup do
      model =
        ChatLanguageModel.new(
          "gpt-4",
          %{},
          %{
            provider: "openai",
            headers: fn -> %{"Authorization" => "Bearer test"} end,
            url: fn %{path: path} -> "https://api.openai.com/v1#{path}" end
          }
        )

      %{model: model}
    end

    test "creates a model with correct configuration", %{model: model} do
      assert model.model_id == "gpt-4"
      assert model.settings == %{}
      assert model.config.provider == "openai"
    end

    test "retrieves specification version" do
      assert ChatLanguageModel.specification_version() == "v1"
    end

    test "supports structured outputs", %{model: model} do
      assert ChatLanguageModel.supports_structured_outputs?(model) == false
    end

    test "default object generation mode", %{model: model} do
      assert ChatLanguageModel.default_object_generation_mode(model) == :tool
    end

    test "retrieves provider information", %{model: model} do
      assert ChatLanguageModel.provider(model) == "openai"
    end

    test "supports image URLs", %{model: model} do
      assert ChatLanguageModel.supports_image_urls?(model) == true
    end
  end

  describe "generation" do
    setup do
      model =
        ChatLanguageModel.new(
          "gpt-4",
          %{},
          %{
            provider: "openai",
            headers: fn -> %{"Authorization" => "Bearer test"} end,
            url: fn %{path: path} -> "https://api.openai.com/v1#{path}" end
          }
        )

      %{model: model}
    end

    test "handles successful generation", %{model: model} do
      # Define a mock response to return
      mock_response = %{
        "id" => "chatcmpl-abc123",
        "object" => "chat.completion",
        "created" => 1_677_858_242,
        "model" => "gpt-4",
        "usage" => %{
          "prompt_tokens" => 10,
          "completion_tokens" => 20,
          "total_tokens" => 30
        },
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" => "Hello, world!"
            },
            "finish_reason" => "stop",
            "index" => 0
          }
        ]
      }

      # Setup the mock adapter to return our response
      expect(Tesla.MockAdapter, :call, fn %{method: :post} = env, _opts ->
        # Assert that we're making the right request
        assert env.url == "https://api.openai.com/v1/chat/completions"

        # Return a successful response
        {:ok, %Tesla.Env{status: 200, body: mock_response}}
      end)

      # Set up the options
      options = %{
        mode: %{type: :regular},
        prompt: [{:user, [%{type: :text, text: "Hello, world!"}]}],
        max_tokens: 100,
        temperature: 0.7,
        top_p: 1.0,
        top_k: nil,
        frequency_penalty: 0.0,
        presence_penalty: 0.0,
        stop_sequences: nil,
        response_format: nil,
        seed: nil,
        provider_metadata: %{}
      }

      # Make the request
      assert {:ok, result} = ChatLanguageModel.do_generate(model, options)

      # Verify the result
      assert result.text == "Hello, world!"
      assert result.finish_reason == "stop"
      assert result.usage == %{prompt_tokens: 10, completion_tokens: 20, total_tokens: 30}
    end

    test "handles error response", %{model: _model} do
      # TODO: Implement error handling test
    end
  end

  describe "streaming" do
    setup do
      # Import the mock module for EventSource
      import Mox

      # Set expectations to allow the caller process
      # This lets tests set expectations on their own processes
      Mox.allow(AI.Provider.Utils.EventSourceMock, self(), Process.whereis(AI.Finch))

      model =
        ChatLanguageModel.new(
          "gpt-4",
          %{},
          %{
            provider: "openai",
            headers: fn -> %{"Authorization" => "Bearer test"} end,
            url: fn %{path: path} -> "https://api.openai.com/v1#{path}" end
          }
        )

      %{model: model}
    end

    test "handles streaming", %{model: model} do
      # Create a finite stream that we can collect from without blocking
      test_stream = [
        {:text_delta, "Hello"},
        {:text_delta, ", "},
        {:text_delta, "world"},
        {:text_delta, "!"},
        {:finish, "stop"}
      ]

      # Create a mock response that provides a non-blocking stream
      mock_response =
        {:ok,
         %{
           status: 200,
           body: "Streaming initialized",
           stream: test_stream,
           config: model.config,
           headers: %{},
           model: model.model_id
         }}

      # Use module-under-test pattern to inject our mock
      old_event_source_module =
        Application.get_env(:ai_sdk, :event_source_module, AI.Provider.Utils.EventSource)

      Application.put_env(:ai_sdk, :event_source_module, AI.Provider.Utils.EventSourceMock)

      # Setup the event source mock expectation
      AI.Provider.Utils.EventSourceMock
      |> expect(:post, fn _url, _body, _headers, _options -> mock_response end)

      try do
        # Set up the options for the test
        options = %{
          mode: %{type: :regular},
          prompt: [{:user, [%{type: :text, text: "Hello, world!"}]}],
          max_tokens: 100,
          temperature: 0.7,
          top_p: 1.0,
          top_k: nil,
          frequency_penalty: 0.0,
          presence_penalty: 0.0,
          stop_sequences: nil,
          response_format: nil,
          seed: nil,
          provider_metadata: %{}
        }

        # Execute the stream call
        {:ok, result} = ChatLanguageModel.do_stream(model, options)

        # Verify the results
        assert is_function(result.stream)

        # Verify other result properties
        assert result.raw_call != nil
        assert result.warnings == []
      after
        # Restore the original module
        Application.put_env(:ai_sdk, :event_source_module, old_event_source_module)
      end
    end

    test "handles streaming error", %{model: model} do
      # Create a mock error response
      mock_error_response = {:error, "Connection error"}

      # Use module-under-test pattern to inject our mock
      old_event_source_module =
        Application.get_env(:ai_sdk, :event_source_module, AI.Provider.Utils.EventSource)

      Application.put_env(:ai_sdk, :event_source_module, AI.Provider.Utils.EventSourceMock)

      # Setup the event source mock expectation
      AI.Provider.Utils.EventSourceMock
      |> expect(:post, fn _url, _body, _headers, _options -> mock_error_response end)

      try do
        # Options for the test
        options = %{
          mode: %{type: :regular},
          prompt: [{:user, [%{type: :text, text: "Hello"}]}],
          max_tokens: 100,
          temperature: 0.7,
          top_p: 1.0,
          top_k: nil,
          frequency_penalty: 0.0,
          presence_penalty: 0.0,
          stop_sequences: nil,
          response_format: nil,
          seed: nil,
          provider_metadata: %{}
        }

        # Call function under test
        result = ChatLanguageModel.do_stream(model, options)

        # Verify error is correctly passed through
        assert result == {:error, "Connection error"}
      after
        # Restore the original module
        Application.put_env(:ai_sdk, :event_source_module, old_event_source_module)
      end
    end
  end
end
