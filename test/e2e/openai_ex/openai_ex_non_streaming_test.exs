defmodule AI.OpenAIExNonStreamingTest do
  use ExUnit.Case

  # This test requires an actual OpenAI API key
  # It's tagged as e2e and will be skipped unless explicitly included
  @moduletag :e2e

  @api_key System.get_env("OPENAI_API_KEY")

  describe "openai_ex non-streaming" do
    @tag :e2e
    test "simple non-streaming request with openai_ex library" do
      # Skip test if no API key is available
      if is_nil(@api_key) do
        IO.puts("Skipping test - no OPENAI_API_KEY environment variable set")
        flunk("Skipping test - no OPENAI_API_KEY environment variable set")
      end

      # Define a simple prompt that will produce a substantial response
      prompt = "Explain the blue sky phenomenon in one sentence."

      # Create client
      IO.puts("\nCreating openai_ex client...")
      openai_ex_client = OpenaiEx.new(@api_key)

      # Create request params - NON-STREAMING
      openai_ex_params = %{
        model: "gpt-4o-mini",
        messages: [
          %{role: "system", content: "You are a helpful, concise assistant."},
          %{role: "user", content: prompt}
        ],
        max_tokens: 100,
        temperature: 0.7
      }

      # Make non-streaming request directly with openai_ex
      IO.puts("Making non-streaming request with openai_ex...")

      result =
        try do
          response = OpenaiEx.Chat.Completions.create!(openai_ex_client, openai_ex_params)
          IO.puts("Response raw: #{inspect(response)}")

          # Extract the content from the response
          content = get_in(response, ["choices", Access.at(0), "message", "content"])
          IO.puts("\nResponse content from openai_ex: #{content}")

          {:ok, content}
        rescue
          e ->
            IO.puts("Error with openai_ex request: #{inspect(e)}")
            {:error, e}
        end

      # Assert we got a successful response
      case result do
        {:ok, content} ->
          assert content != "", "Response content should not be empty"

        {:error, _} ->
          flunk("Failed to get response from openai_ex")
      end
    end
  end
end
