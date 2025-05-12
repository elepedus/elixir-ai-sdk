defmodule AI.Stream.EventTest do
  use ExUnit.Case

  alias AI.Stream.Event

  describe "TextDelta" do
    test "creates a text delta event" do
      event = %Event.TextDelta{content: "Hello"}
      assert event.content == "Hello"
    end
  end

  describe "ToolCall" do
    test "creates a tool call event" do
      event = %Event.ToolCall{id: "123", name: "search", arguments: "{\"query\": \"weather\"}"}
      assert event.id == "123"
      assert event.name == "search"
      assert event.arguments == "{\"query\": \"weather\"}"
    end
  end

  describe "Finish" do
    test "creates a finish event" do
      event = %Event.Finish{reason: "stop"}
      assert event.reason == "stop"
    end
  end

  describe "Metadata" do
    test "creates a metadata event" do
      metadata = %{usage: %{tokens: 120}}
      event = %Event.Metadata{data: metadata}
      assert event.data == metadata
    end
  end

  describe "Error" do
    test "creates an error event" do
      error = %{message: "API rate limit exceeded"}
      event = %Event.Error{error: error}
      assert event.error == error
    end
  end

  describe "serialization/deserialization" do
    test "converts TextDelta to tuple format" do
      event = %Event.TextDelta{content: "Hello"}
      assert Event.to_tuple(event) == {:text_delta, "Hello"}
    end

    test "converts ToolCall to tuple format" do
      event = %Event.ToolCall{id: "123", name: "search", arguments: "{\"query\": \"weather\"}"}

      assert Event.to_tuple(event) ==
               {:tool_call, %{id: "123", name: "search", arguments: "{\"query\": \"weather\"}"}}
    end

    test "converts Finish to tuple format" do
      event = %Event.Finish{reason: "stop"}
      assert Event.to_tuple(event) == {:finish, "stop"}
    end

    test "converts Metadata to tuple format" do
      metadata = %{usage: %{tokens: 120}}
      event = %Event.Metadata{data: metadata}
      assert Event.to_tuple(event) == {:metadata, metadata}
    end

    test "converts Error to tuple format" do
      error = %{message: "API rate limit exceeded"}
      event = %Event.Error{error: error}
      assert Event.to_tuple(event) == {:error, error}
    end

    test "creates Event struct from tuple" do
      assert Event.from_tuple({:text_delta, "Hello"}) == %Event.TextDelta{content: "Hello"}

      assert Event.from_tuple(
               {:tool_call, %{id: "123", name: "search", arguments: "{\"query\": \"weather\"}"}}
             ) ==
               %Event.ToolCall{id: "123", name: "search", arguments: "{\"query\": \"weather\"}"}

      assert Event.from_tuple({:finish, "stop"}) == %Event.Finish{reason: "stop"}

      assert Event.from_tuple({:metadata, %{usage: %{tokens: 120}}}) == %Event.Metadata{
               data: %{usage: %{tokens: 120}}
             }

      assert Event.from_tuple({:error, %{message: "API rate limit exceeded"}}) == %Event.Error{
               error: %{message: "API rate limit exceeded"}
             }
    end
  end
end
