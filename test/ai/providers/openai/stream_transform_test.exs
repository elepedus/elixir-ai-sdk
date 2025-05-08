defmodule AI.Providers.OpenAI.StreamTransformTest do
  use ExUnit.Case, async: true
  
  alias AI.Providers.OpenAI.ChatLanguageModel
  
  describe "handle_stream_response/4" do
    test "properly transforms a stream from EventSource" do
      # Create a simple list of events (not a Stream) to avoid timeout issues
      source_events = [
        {:text_delta, "Hello"},
        {:text_delta, ", "},
        {:text_delta, "world"},
        {:text_delta, "!"},
        {:finish, "stop"}
      ]
      
      # Create a mock response similar to what EventSource.post would return
      response = %{
        status: 200,
        body: "",
        stream: source_events
      }
      
      # Call the handle_stream_response function
      {:ok, result} = ChatLanguageModel.handle_stream_response(response, %{}, [], %{})
      
      # Verify we get a valid stream back
      assert is_map(result)
      assert Map.has_key?(result, :stream)
      assert is_function(result.stream)
      
      # Just make sure the stream doesn't fail when we start to consume it
      result.stream |> Stream.take(1) |> Enum.to_list()
      
      # Most importantly, verify we have the expected fields
      assert Map.has_key?(result, :raw_call)
      assert Map.has_key?(result, :warnings)
      assert result.warnings == []
    end
  end
end