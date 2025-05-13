defmodule AI.SDKSimpleTest do
  use ExUnit.Case

  # This test requires an actual OpenAI API key
  # It's tagged as e2e and will be skipped unless explicitly included
  @moduletag :e2e

  @api_key System.get_env("OPENAI_API_KEY")

  describe "OpenAI with AI SDK" do
    @tag :e2e
    test "non-streaming request with AI SDK" do
      # Skip test if no API key is available
      if is_nil(@api_key) do
        IO.puts("Skipping test - no OPENAI_API_KEY environment variable set")
        flunk("Skipping test - no OPENAI_API_KEY environment variable set")
      end

      # Define a simple prompt that will produce a substantial response
      prompt = "Explain the blue sky phenomenon in one sentence."

      IO.puts("\nCreating AI SDK OpenAI model...")
      model = AI.openai("gpt-4o-mini", api_key: @api_key)

      # Make non-streaming request with our SDK
      IO.puts("Making non-streaming request with AI SDK...")

      result =
        try do
          {:ok, response} =
            AI.generate_text(%{
              model: model,
              system: "You are a helpful, concise assistant.",
              prompt: prompt,
              max_tokens: 100,
              temperature: 0.7
            })

          IO.puts("Response raw: #{inspect(response)}")
          IO.puts("\nResponse content from AI SDK: #{response.text}")

          {:ok, response.text}
        rescue
          e ->
            IO.puts("Error with AI SDK request: #{inspect(e)}")
            {:error, e}
        end

      # Assert we got a successful response
      case result do
        {:ok, content} ->
          assert content != "", "Response content should not be empty"

        {:error, _} ->
          flunk("Failed to get response from AI SDK")
      end
    end

    @tag :e2e
    test "streaming request with AI SDK" do
      # Skip test if no API key is available
      if is_nil(@api_key) do
        IO.puts("Skipping test - no OPENAI_API_KEY environment variable set")
        flunk("Skipping test - no OPENAI_API_KEY environment variable set")
      end

      # Define a simple prompt that will produce a substantial response
      prompt = "Explain the blue sky phenomenon in one sentence."

      IO.puts("\nCreating AI SDK OpenAI model...")
      model = AI.openai("gpt-4o-mini", api_key: @api_key)

      # Make streaming request with our SDK
      IO.puts("Making streaming request with AI SDK...")

      stream_result =
        try do
          {:ok, response} =
            AI.stream_text(%{
              model: model,
              system: "You are a helpful, concise assistant.",
              prompt: prompt,
              max_tokens: 100,
              temperature: 0.7
            })

          IO.puts("Stream response structure: #{inspect(response)}")

          # Collect the stream content
          IO.puts("\nCollecting stream content:")

          content_chunks =
            response.stream
            |> Enum.reduce_while([], fn
              {:text_delta, chunk}, acc ->
                IO.write(chunk)
                {:cont, [chunk | acc]}

              {:finish, reason}, acc ->
                IO.puts("\nFinished streaming: #{reason}")
                {:halt, acc}

              _, acc ->
                {:cont, acc}
            end)
            |> Enum.reverse()

          content = Enum.join(content_chunks, "")

          IO.puts("\nComplete stream content: #{content}")
          {:ok, content}
        rescue
          e ->
            IO.puts("Error with AI SDK streaming request: #{inspect(e)}")
            {:error, e}
        end

      # Assert we got a successful response
      case stream_result do
        {:ok, content} ->
          assert content != "", "Stream content should not be empty"

        {:error, _} ->
          flunk("Failed to get streaming response from AI SDK")
      end
    end
  end
end
