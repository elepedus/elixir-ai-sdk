defmodule AI.StreamTextIntegrationTest do
  use ExUnit.Case, async: true

  describe "AI.stream_text/1 with mock provider" do
    test "properly streams text from a mock model" do
      # Create a mock model that returns a simple stream
      mock_model = %AI.Core.MockLanguageModel{
        do_stream: fn _opts ->
          # Create a stream with predefined chunks
          stream =
            Stream.resource(
              # Initialize function returns a list of events to emit
              fn ->
                [
                  {:text_delta, "Hello"},
                  {:text_delta, ", "},
                  {:text_delta, "world"},
                  {:text_delta, "!"},
                  {:finish, "stop"}
                ]
              end,
              # Producer function returns the next event or halts
              fn
                [] -> {:halt, []}
                [event | rest] -> {[event], rest}
              end,
              # Cleanup function (does nothing here)
              fn _ -> :ok end
            )

          # Return successful response with the stream
          {:ok,
           %{
             stream: stream,
             warnings: [],
             raw_call: %{}
           }}
        end
      }

      # Call stream_text with our mock model
      {:ok, result} =
        AI.stream_text(%{
          model: mock_model,
          prompt: "Say hello world"
        })

      # Verify we got a valid result with a stream
      assert is_map(result)
      assert Map.has_key?(result, :stream)

      # Collect all events from the stream
      events = Enum.to_list(result.stream)

      # Verify we got the expected number of events
      assert length(events) == 5

      # Verify the events are in the correct order and format
      assert Enum.at(events, 0) == {:text_delta, "Hello"}
      assert Enum.at(events, 1) == {:text_delta, ", "}
      assert Enum.at(events, 2) == {:text_delta, "world"}
      assert Enum.at(events, 3) == {:text_delta, "!"}
      assert Enum.at(events, 4) == {:finish, "stop"}
    end
  end
end
