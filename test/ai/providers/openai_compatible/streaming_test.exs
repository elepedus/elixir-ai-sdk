defmodule AI.Providers.OpenAICompatible.StreamingTest do
  use ExUnit.Case, async: true
  import Mox

  alias AI.Providers.OpenAICompatible.Provider
  alias AI.Providers.OpenAICompatible.ChatLanguageModel

  # Make sure Mox is set up for Tesla
  setup :verify_on_exit!

  describe "do_stream/2 with EventSource mock" do
    setup do
      # Store original EventSource module and set our mock
      old_event_source_module =
        Application.get_env(:ai_sdk, :event_source_module, AI.Provider.Utils.EventSource)

      Application.put_env(:ai_sdk, :event_source_module, AI.Provider.Utils.EventSourceMock)

      # Reset any expectations from previous tests
      Mox.verify_on_exit!()

      # Create test model
      provider =
        Provider.new(%{
          base_url: "https://api.example.com",
          name: "test-provider",
          api_key: "test-api-key"
        })

      model =
        ChatLanguageModel.new(provider, %{
          model_id: "gpt-3.5-turbo"
        })

      # Cleanup after test
      on_exit(fn ->
        Application.put_env(:ai_sdk, :event_source_module, old_event_source_module)
      end)

      %{model: model}
    end

    test "properly passes errors from EventSource", %{model: model} do
      # Create a mock error response
      mock_error_response = {:error, "Simulated connection error"}

      # Setup the EventSource mock to return our error
      AI.Provider.Utils.EventSourceMock
      |> expect(:post, fn _url, _body, _headers, _options ->
        mock_error_response
      end)

      # Call do_stream with regular options
      options = %{
        messages: [%{role: "user", content: "Hello"}]
      }

      # Execute the function
      result = ChatLanguageModel.do_stream(model, options)

      # Verify we get the error
      assert match?({:error, "Simulated connection error"}, result)
    end

    test "successfully streams text", %{model: model} do
      # Create a predetermined stream of events
      mock_stream = [
        {:text_delta, "Hello"},
        {:text_delta, ", "},
        {:text_delta, "world"},
        {:text_delta, "!"},
        {:finish, "stop"}
      ]

      # Create a mock success response
      mock_response =
        {:ok,
         %{
           status: 200,
           body: "Streaming initialized",
           stream: mock_stream
         }}

      # Setup the EventSource mock to return our successful response
      AI.Provider.Utils.EventSourceMock
      |> expect(:post, fn _url, _body, _headers, _options ->
        mock_response
      end)

      # Call do_stream with regular options
      options = %{
        messages: [%{role: "user", content: "Hello"}]
      }

      # Execute the function
      {:ok, result} = ChatLanguageModel.do_stream(model, options)

      # Verify we have a stream
      assert is_map(result)
      assert Map.has_key?(result, :stream)

      # The response stream should be a Stream struct or a function
      assert is_map(result.stream) or is_function(result.stream)

      # Verify other properties
      assert Map.has_key?(result, :raw_response)
      assert Map.has_key?(result, :warnings)
    end
  end
end
