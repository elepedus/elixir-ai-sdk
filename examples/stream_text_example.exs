# Sample script demonstrating AI.stream_text usage
# Run from the elixir-ai-sdk root directory with: 
# mix run examples/stream_text_example.exs

# Make sure you've set the OPENAI_API_KEY environment variable
# or replace System.get_env("OPENAI_API_KEY") with your actual API key

defmodule StreamTextExample do
  def run do
    IO.puts("Starting stream_text example...\n")

    # Get API key from environment
    api_key = System.get_env("OPENAI_API_KEY")
    
    if is_nil(api_key) do
      IO.puts("Error: OPENAI_API_KEY environment variable not set")
      System.halt(1)
    end

    prompt = "Invent a new holiday and describe its traditions."

    # Create the request
    case AI.stream_text(%{
      model: AI.openai("gpt-3.5-turbo", api_key: api_key),
      prompt: prompt,
      temperature: 0.3,
      max_tokens: 512
    }) do
      {:ok, result} ->
        IO.puts("Stream started successfully. Generating text for prompt: \"#{prompt}\"\n")

        IO.puts(Enum.join(result.stream, ""))

      {:error, error} ->
        IO.puts("Failed to start streaming: #{inspect(error)}")
    end
  end
end

# Run the example
StreamTextExample.run()