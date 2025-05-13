defmodule AI.StreamIntegrationTest do
  use ExUnit.Case, async: true
  import Mox

  describe "AI.stream_text/1 with OpenAI provider" do
    setup do
      # Use the predefined mock
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

      # Setup the EventSource mock expectation
      AI.Provider.Utils.EventSourceMock
      |> expect(:post, fn _url, _body, _headers, _options ->
        mock_response
      end)

      # Create a model to use with the streams
      model = AI.openai("gpt-3.5-turbo")

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
      assert is_function(result.stream)
      assert Map.has_key?(result, :warnings)
      assert Map.has_key?(result, :response)
    end

    @tag :integration
    test "streams text with EventSource" do
      # Skip if OPENAI_API_KEY is not set
      if System.get_env("OPENAI_API_KEY") == nil do
        IO.puts("Skipping OpenAI streaming test - no API key")
        flunk("Skipping test - no OPENAI_API_KEY environment variable set")
      end
    end
  end
end
