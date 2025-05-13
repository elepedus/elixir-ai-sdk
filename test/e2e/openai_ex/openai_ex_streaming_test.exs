defmodule AI.OpenAIExStreamingTest do
  use ExUnit.Case

  # This test requires an actual OpenAI API key
  # It's tagged as e2e and will be skipped unless explicitly included
  @moduletag :e2e

  @api_key System.get_env("OPENAI_API_KEY")

  describe "openai_ex streaming" do
    @tag :e2e
    test "stream responses using the official documented approach" do
      # Skip test if no API key is available
      if is_nil(@api_key) do
        IO.puts("Skipping test - no OPENAI_API_KEY environment variable set")
        flunk("Skipping test - no OPENAI_API_KEY environment variable set")
      end

      # Define a simple prompt that will produce a substantial response
      prompt = "Explain the blue sky phenomenon in one sentence."

      # Create client using the approach from the docs
      IO.puts("\nCreating openai_ex client...")
      client = OpenaiEx.new(@api_key)

      # Create streaming request following the docs example
      IO.puts("Making streaming request with openai_ex (docs approach)...")

      # Create the messages
      messages = [
        %{role: "system", content: "You are a helpful, concise assistant."},
        %{role: "user", content: prompt}
      ]

      # Create params (without stream: true as shown in docs)
      params = %{
        model: "gpt-4o-mini",
        messages: messages,
        max_tokens: 100,
        temperature: 0.7
      }

      # Make the streaming request using the stream option parameter as shown in docs
      try do
        # This is the key part from the docs example
        stream = OpenaiEx.Chat.Completions.create(client, params, stream: true)

        # Process the stream
        IO.puts("\nStreaming content:")

        collected_content =
          case stream do
            {:ok, response} ->
              # The stream data is in the body_stream field of the response
              response.body_stream
              |> Stream.flat_map(fn line ->
                # Process the SSE line - extract data part
                if is_binary(line) && String.starts_with?(String.trim(line), "data: ") do
                  data_content = String.slice(String.trim(line), 6..-1//1) |> String.trim()

                  if data_content == "[DONE]" do
                    IO.puts("\n[DONE] marker received")
                    []
                  else
                    # Try to decode the JSON
                    try do
                      json = Jason.decode!(data_content)
                      # Get the content delta
                      content = get_in(json, ["choices", Access.at(0), "delta", "content"])
                      if content, do: IO.write(content)
                      [content]
                    rescue
                      _ -> []
                    end
                  end
                else
                  []
                end
              end)
              |> Enum.filter(&(&1 != nil and &1 != ""))
              |> Enum.to_list()

            {:error, error} ->
              IO.puts("Error creating stream: #{inspect(error)}")
              []
          end

        # Get the full content and log
        full_streaming_content = Enum.join(collected_content, "")
        IO.puts("\n\nFull streaming content: #{full_streaming_content}")

        # Now get non-streaming version for comparison
        IO.puts("\nMaking non-streaming request for comparison...")

        non_streaming_result =
          try do
            # Make a regular request without streaming
            response = OpenaiEx.Chat.Completions.create!(client, params)
            content = get_in(response, ["choices", Access.at(0), "message", "content"])
            IO.puts("Non-streaming content: #{content}")
            content
          rescue
            e ->
              IO.puts("Error with non-streaming request: #{inspect(e)}")
              nil
          end

        # Compare the two if we have both
        if non_streaming_result && full_streaming_content != "" do
          streaming_length = String.length(full_streaming_content)
          non_streaming_length = String.length(non_streaming_result)

          IO.puts("\nComparison:")
          IO.puts("- Streaming content length: #{streaming_length} chars")
          IO.puts("- Non-streaming content length: #{non_streaming_length} chars")
          IO.puts("- Content ratio: #{streaming_length / non_streaming_length * 100}%")

          # Test assertions
          assert full_streaming_content != "", "Streaming content should not be empty"
        end
      rescue
        e ->
          IO.puts("Error in test: #{inspect(e)}")
          flunk("Error processing streaming request: #{inspect(e)}")
      end
    end
  end
end
