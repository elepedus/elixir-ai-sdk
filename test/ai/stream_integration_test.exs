defmodule AI.StreamIntegrationTest do
  use ExUnit.Case, async: true
  import Mox

  describe "AI.stream_text/1 with OpenAI provider" do
    setup do
      # Use the predefined mock for EventSource
      old_event_source_module =
        Application.get_env(:ai_sdk, :event_source_module, AI.Provider.Utils.EventSource)

      Application.put_env(:ai_sdk, :event_source_module, AI.Provider.Utils.EventSourceMock)

      # Make sure expectations are verified
      Mox.verify_on_exit!()

      # Return cleanup function
      on_exit(fn ->
        Application.put_env(:ai_sdk, :event_source_module, old_event_source_module)
      end)

      :ok
    end

    test "successfully streams text with mocked responses" do
      # Create predetermined mock events as a list (not a stream)
      mock_events = [
        {:text_delta, "Hello"},
        {:text_delta, "! "},
        {:text_delta, "How can I "},
        {:text_delta, "assist you "},
        {:text_delta, "today?"},
        {:finish, "stop"}
      ]

      # Create mock response with our events
      mock_response =
        {:ok,
         %{
           status: 200,
           body: "Streaming initialized",
           stream: mock_events
         }}

      # Create an OpenAI model
      # But override the Tesla client to simulate a working response
      headers_fn = fn -> %{"Authorization" => "Bearer test-key"} end
      url_fn = fn %{path: path} -> "https://api.openai.com/v1#{path}" end

      model =
        AI.Providers.OpenAI.ChatLanguageModel.new(
          "gpt-3.5-turbo",
          %{},
          %{
            provider: "openai",
            headers: headers_fn,
            url: url_fn
          }
        )

      # Setup the EventSource mock expectation
      AI.Provider.Utils.EventSourceMock
      |> expect(:post, fn _url, _body, _headers, _options ->
        mock_response
      end)

      # Call stream_text to test
      {:ok, result} =
        AI.stream_text(%{
          model: model,
          prompt: "Say hello",
          max_tokens: 50
        })

      # Verify we get a valid result map
      assert is_map(result)
      assert Map.has_key?(result, :stream)
      assert is_map(result.stream) or is_function(result.stream)
      assert Map.has_key?(result, :warnings)
      assert Map.has_key?(result, :response)
    end
  end
end
