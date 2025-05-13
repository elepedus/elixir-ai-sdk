defmodule AI.StreamTextOpenAIE2ETest do
  use ExUnit.Case

  # This test requires an actual OpenAI API key
  # It's tagged as e2e and will be skipped unless explicitly included
  @moduletag :e2e

  @api_key System.get_env("OPENAI_API_KEY")

  describe "AI.stream_text with OpenAI provider" do
    @tag :e2e
    test "streams text using AI.stream_text with OpenAI provider" do
      # Create an OpenAI model using our SDK
      model = AI.openai("gpt-4o-mini", api_key: @api_key)

      # Define a simple prompt that will produce a substantial response
      prompt = "Explain the blue sky phenomenon in one sentence."

      # Make streaming request using our AI.stream_text function
      IO.puts("\nMaking streaming request using AI.stream_text with OpenAI provider...")

      result =
        try do
          # Make the streaming request
          {:ok, response} =
            AI.stream_text(%{
              model: model,
              system: "You are a helpful, concise assistant.",
              prompt: prompt,
              max_tokens: 100,
              temperature: 0.7
            })

          IO.puts(
            "\nGot stream response - metadata: #{inspect(Map.drop(response, [:stream]), pretty: true, limit: 1000)}"
          )

          # Process the stream to collect content
          chunks = collect_stream_content(response.stream)

          # Join all chunks into the full response
          full_content = Enum.join(chunks, "")

          IO.puts("\nFull streaming content: #{full_content}")

          {:ok, full_content, chunks}
        rescue
          e ->
            IO.puts("Error with streaming request: #{inspect(e)}")
            {:error, e}
        end

      # Assert we got a successful response
      case result do
        {:ok, content, chunks} ->
          # Verify we have a non-empty content
          assert content != "", "Streaming content should not be empty"
          assert is_binary(content), "Streaming content should be a string"

          # Verify we received multiple chunks (streaming worked)
          assert length(chunks) > 1, "Should have received multiple stream chunks"

        {:error, _} ->
          flunk("Failed to get streaming response")
      end
    end
  end

  # Helper function to collect content from the stream
  defp collect_stream_content(stream) do
    IO.puts("\nCollecting stream content...")

    result =
      Enum.reduce_while(stream, [], fn
        # Got a text chunk, add it to our accumulator and continue
        chunk, acc when is_binary(chunk) ->
          # Print the chunk as it arrives
          IO.write(chunk)
          {:cont, [chunk | acc]}

        # Something else. just add it and continue
        other, acc ->
          IO.puts("\nOther event: #{inspect(other)}")
          {:cont, [other | acc]}
      end)
      # Reverse to maintain order
      |> Enum.reverse()

    IO.puts("\nCollected #{length(result)} stream chunks")
    result
  end
end
