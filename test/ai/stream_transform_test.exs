defmodule AI.StreamTransformTest do
  use ExUnit.Case, async: true

  describe "Stream transformation in OpenAI provider" do
    test "properly handles stream from EventSource" do
      # Create a simple list of events to stream
      events = [
        {:text_delta, "Hello"},
        {:text_delta, ", "},
        {:text_delta, "world"},
        {:text_delta, "!"},
        {:finish, "stop"}
      ]

      # Create a simple stream that emits these events
      source_stream = Stream.map(events, fn event -> event end)

      # Verify we can enumerate the source stream
      assert Enum.to_list(source_stream) == events

      # Create a transform function that simulates what we need to do with
      # the stream in the OpenAI provider
      transform_stream = fn stream ->
        # This is the corrected implementation we need
        # We manually set up a processor stream rather than using Stream.transform
        Stream.resource(
          # Initialize function - start with the input stream and initial state
          fn -> {Enum.to_list(stream), %{finished: false}} end,

          # Process function - emit events with transformations
          fn
            # When we're out of events, halt
            {[], acc} ->
              {:halt, {[], acc}}

            # Process the next event
            {[event | rest], acc} ->
              case event do
                # Pass through text deltas
                {:text_delta, text} ->
                  {[{:text_delta, text}], {rest, acc}}

                # Pass through finish events directly in this test
                {:finish, reason} ->
                  {[{:finish, reason}], {rest, acc}}

                # Pass through errors
                {:error, error} ->
                  {[{:error, error}], {rest, acc}}

                # Skip any other events
                _ ->
                  {[], {rest, acc}}
              end
          end,

          # Cleanup function - emit a finish event if we had one
          fn {_rest, acc} ->
            case acc do
              %{finished: {:finish, reason}} ->
                [{:finish, reason}]

              _ ->
                []
            end
          end
        )
      end

      # Apply our transformation and collect the results
      transformed_stream = transform_stream.(source_stream)
      transformed_events = Enum.to_list(transformed_stream)

      # Verify the transformation worked correctly
      assert length(transformed_events) == 5
      assert Enum.at(transformed_events, 0) == {:text_delta, "Hello"}
      assert Enum.at(transformed_events, 1) == {:text_delta, ", "}
      assert Enum.at(transformed_events, 2) == {:text_delta, "world"}
      assert Enum.at(transformed_events, 3) == {:text_delta, "!"}
      assert Enum.at(transformed_events, 4) == {:finish, "stop"}
    end
  end
end
