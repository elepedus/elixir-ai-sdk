defmodule AI.StreamTextTest do
  use ExUnit.Case, async: true

  alias AI.Core.MockLanguageModel

  describe "AI.stream_text/1" do
    test "initializes a basic text stream with mock model" do
      # Create a mock model that returns a simple stream
      mock_model =
        MockLanguageModel.new(%{
          do_stream: fn _opts ->
            stream =
              Stream.unfold(["Hello", ", ", "world", "!"], fn
                [] -> nil
                [chunk | rest] -> {{:text_delta, chunk}, rest}
              end)

            {:ok, %{stream: stream, warnings: []}}
          end
        })

      # Call the stream_text function with the mock model
      {:ok, result} =
        AI.stream_text(%{
          model: mock_model,
          prompt: "Hello there"
        })

      # Debug what we're getting back
      IO.inspect(result, label: "Stream Text Result")

      # Check that a stream is returned
      assert is_function(result.stream) or is_struct(result.stream, Stream)

      # Consume the stream and check content
      chunks = Enum.to_list(result.stream)
      IO.inspect(chunks, label: "Stream Chunks")

      assert chunks == [
               {:text_delta, "Hello"},
               {:text_delta, ", "},
               {:text_delta, "world"},
               {:text_delta, "!"}
             ]
    end

    test "streams text from OpenAI provider" do
      # Use the existing EventSource mock

      # Set up mock to be used in place of EventSource
      old_event_source_module =
        Application.get_env(:ai_sdk, :event_source_module, AI.Provider.Utils.EventSource)

      Application.put_env(:ai_sdk, :event_source_module, AI.Provider.Utils.EventSourceMock)

      try do
        # Create OpenAI model
        model = AI.openai("gpt-3.5-turbo")

        # Create a predetermined stream of events for our mock
        mock_events = [
          {:text_delta, "Streaming in Elixir "},
          {:text_delta, "is a powerful feature "},
          {:text_delta, "that allows processing data"},
          {:text_delta, " as it becomes available."},
          {:finish, "stop"}
        ]

        # Create a mock success response
        mock_response =
          {:ok,
           %{
             status: 200,
             body: "Streaming initialized",
             stream: mock_events
           }}

        # Setup the EventSource mock to return our response
        AI.Provider.Utils.EventSourceMock
        |> Mox.expect(:post, fn _url, _body, _headers, _options ->
          mock_response
        end)

        # Call the stream_text function
        {:ok, result} =
          AI.stream_text(%{
            model: model,
            prompt: "Tell me about streaming in Elixir"
          })

        # Verify stream is returned
        assert is_function(result.stream) or is_struct(result.stream, Stream)

        # Verify we get the expected fields
        assert Map.has_key?(result, :warnings)
        assert Map.has_key?(result, :response)
      after
        # Restore original module
        Application.put_env(:ai_sdk, :event_source_module, old_event_source_module)
      end
    end

    test "handles streaming errors gracefully" do
      # Create a mock model that returns an error
      mock_model =
        MockLanguageModel.new(%{
          do_stream: fn _opts ->
            {:error, "Simulated streaming error"}
          end
        })

      # Call the stream_text function with the mock model
      result =
        AI.stream_text(%{
          model: mock_model,
          prompt: "This should fail"
        })

      # Verify we get the expected error
      assert {:error, "Simulated streaming error"} = result
    end

    test "streams with system message correctly" do
      # Create a mock model that returns a simple stream
      mock_model =
        MockLanguageModel.new(%{
          do_stream: fn opts ->
            # Check if the system message was received and converted properly
            assert Enum.any?(opts.messages, fn
                     %{role: "system", content: "You are a helpful assistant."} -> true
                     _ -> false
                   end)

            stream =
              Stream.unfold(["Hello", ", ", "world", "!"], fn
                [] -> nil
                [chunk | rest] -> {{:text_delta, chunk}, rest}
              end)

            {:ok, %{stream: stream, warnings: []}}
          end
        })

      # Call the stream_text function with the mock model and system message
      {:ok, result} =
        AI.stream_text(%{
          model: mock_model,
          system: "You are a helpful assistant.",
          prompt: "Tell me about Elixir"
        })

      # Verify stream content
      chunks = Enum.to_list(result.stream)
      assert length(chunks) == 4
    end
  end
end
