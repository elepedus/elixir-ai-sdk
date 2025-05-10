defmodule AI.OpenAIExNonStreamingTest do
  use ExUnit.Case

  # This test requires an actual OpenAI API key
  # It's tagged as e2e and will be skipped unless explicitly included
  @moduletag :e2e

  @api_key System.get_env("OPENAI_API_KEY")

  describe "OpenAI with non-streaming (stream: false)" do
    @tag :e2e
    test "simple non-streaming request using openai_ex" do
      # Skip test if no API key is available
      if is_nil(@api_key) do
        IO.puts("Skipping test - no OPENAI_API_KEY environment variable set")
        flunk("Skipping test - no OPENAI_API_KEY environment variable set")
      end

      # Define a simple prompt that will produce a substantial response
      prompt = "Explain the blue sky phenomenon in one sentence."

      # Create the OpenAI client
      openai_client = OpenaiEx.new(@api_key)

      # Create the messages
      messages = [
        OpenaiEx.ChatMessage.system("You are a helpful, concise assistant."),
        OpenaiEx.ChatMessage.user(prompt)
      ]

      # Create chat completion request
      chat_completion = OpenaiEx.Chat.Completions.new(
        model: "gpt-4o-mini",
        messages: messages,
        max_tokens: 100,
        temperature: 0.7
      )

      # Make non-streaming request directly using the OpenAI library
      IO.puts("\nMaking direct non-streaming request using openai_ex...")

      result = try do
        # Make the request using the OpenAI library
        {:ok, response} = OpenaiEx.Chat.Completions.create(openai_client, chat_completion)

        IO.puts("\nGot response: #{inspect(response, pretty: true)}")

        # Extract the response content
        content = response["choices"]
                  |> List.first()
                  |> Map.get("message")
                  |> Map.get("content")

        IO.puts("\nExtracted content: #{content}")

        {:ok, content}
      rescue
        e ->
          IO.puts("Error with non-streaming request: #{inspect(e)}")
          {:error, e}
      end

      # Assert we got a successful response
      case result do
        {:ok, content} ->
          assert content != "", "Response content should not be empty"
          assert is_binary(content), "Response content should be a string"
        {:error, _} ->
          flunk("Failed to get response from non-streaming API call")
      end
    end
  end
end