defmodule AI.Stream.TransformerTest do
  use ExUnit.Case, async: true

  # Set longer timeout for these tests since they involve stream processing
  @moduletag timeout: 120_000

  alias AI.Stream.Event
  alias AI.Stream.OpenAITransformer
  alias AI.Stream.OpenAICompatibleTransformer

  describe "OpenAITransformer" do
    test "transforms text delta events" do
      # Create a list of events rather than a stream for test stability
      source = [
        {:text_delta, "Hello, "},
        {:text_delta, "world"},
        {:text_delta, "!"}
      ]

      # Transform the list
      transformed = OpenAITransformer.transform(source) |> Enum.to_list()

      # Verify the transformation
      assert length(transformed) == 3
      assert Enum.at(transformed, 0) == %Event.TextDelta{content: "Hello, "}
      assert Enum.at(transformed, 1) == %Event.TextDelta{content: "world"}
      assert Enum.at(transformed, 2) == %Event.TextDelta{content: "!"}
    end

    test "transforms finish events" do
      # Create a list with text followed by a finish event
      source = [
        {:text_delta, "Hello"},
        {:finish, "stop"}
      ]

      # Transform the list
      transformed = OpenAITransformer.transform(source) |> Enum.to_list()

      # Verify the transformation
      assert length(transformed) == 2
      assert Enum.at(transformed, 0) == %Event.TextDelta{content: "Hello"}
      assert Enum.at(transformed, 1) == %Event.Finish{reason: "stop"}
    end

    test "transforms error events" do
      # Create a list with an error event
      source = [
        {:text_delta, "Partial response"},
        {:error, "Connection lost"}
      ]

      # Transform the list
      transformed = OpenAITransformer.transform(source) |> Enum.to_list()

      # Verify the transformation
      assert length(transformed) == 2
      assert Enum.at(transformed, 0) == %Event.TextDelta{content: "Partial response"}
      assert Enum.at(transformed, 1) == %Event.Error{error: "Connection lost"}
    end

    test "handles tool call events" do
      # Create a list with a tool call
      tool_call = %{id: "call_123", name: "get_weather", arguments: ~s({"location": "New York"})}

      source = [
        {:text_delta, "Let me check the weather"},
        {:tool_call, tool_call}
      ]

      # Transform the list
      transformed = OpenAITransformer.transform(source) |> Enum.to_list()

      # Verify the transformation
      assert length(transformed) == 2
      assert Enum.at(transformed, 0) == %Event.TextDelta{content: "Let me check the weather"}

      assert Enum.at(transformed, 1) == %Event.ToolCall{
               id: "call_123",
               name: "get_weather",
               arguments: ~s({"location": "New York"})
             }
    end

    test "handles empty streams" do
      # Empty source should result in empty transformation
      transformed = OpenAITransformer.transform([]) |> Enum.to_list()
      assert transformed == []
    end
  end

  describe "OpenAICompatibleTransformer" do
    test "transforms standard events like OpenAITransformer" do
      # Use a simple list instead of a stream for stability
      source = [
        {:text_delta, "Hello"},
        {:finish, "stop"}
      ]

      # Transform the list
      transformed = OpenAICompatibleTransformer.transform(source) |> Enum.to_list()

      # Verify the transformation
      assert length(transformed) == 2
      assert Enum.at(transformed, 0) == %Event.TextDelta{content: "Hello"}
      assert Enum.at(transformed, 1) == %Event.Finish{reason: "stop"}
    end

    test "detects end of stream when configured" do
      # Use a list of text delta events
      source = [
        {:text_delta, "Hello, "},
        {:text_delta, "world"}
      ]

      # Transform with detect_end_of_stream option
      transformed =
        OpenAICompatibleTransformer.transform(source, %{detect_end_of_stream: true})
        |> Enum.to_list()

      # Verify that a finish event was appended
      assert length(transformed) == 3
      assert Enum.at(transformed, 0) == %Event.TextDelta{content: "Hello, "}
      assert Enum.at(transformed, 1) == %Event.TextDelta{content: "world"}
      assert Enum.at(transformed, 2) == %Event.Finish{reason: "complete"}
    end

    test "extracts content from various metadata formats" do
      # Use a list of different metadata formats
      source = [
        # Content at top level
        {:metadata, %{"content" => "Text from content field"}},
        # Content in text field
        {:metadata, %{"text" => "Text from text field"}},
        # Content in message.content
        {:metadata, %{"message" => %{"content" => "Text from message.content"}}},
        # Regular metadata without content
        {:metadata, %{"some_key" => "some_value"}}
      ]

      # Transform the list with end-of-stream detection enabled
      transformed =
        OpenAICompatibleTransformer.transform(source, %{detect_end_of_stream: true})
        |> Enum.to_list()

      # Verify the transformation - length 5 because of auto-appended finish event
      assert length(transformed) == 5
      assert Enum.at(transformed, 0) == %Event.TextDelta{content: "Text from content field"}
      assert Enum.at(transformed, 1) == %Event.TextDelta{content: "Text from text field"}
      assert Enum.at(transformed, 2) == %Event.TextDelta{content: "Text from message.content"}
      assert Enum.at(transformed, 3) == %Event.Metadata{data: %{"some_key" => "some_value"}}
      assert Enum.at(transformed, 4).reason == "complete"
    end

    test "handles empty streams" do
      # Empty source should result in empty transformation
      transformed = OpenAICompatibleTransformer.transform([]) |> Enum.to_list()
      assert transformed == []
    end
  end
end
