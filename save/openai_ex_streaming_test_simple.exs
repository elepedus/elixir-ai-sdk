defmodule AI.OpenAIExStreamingTestSimple do
  use ExUnit.Case
  
  # This test requires an actual OpenAI API key
  # It's tagged as e2e and will be skipped unless explicitly included
  @moduletag :e2e

  @api_key System.get_env("OPENAI_API_KEY")
  
  describe "OpenAI with streaming (stream: true)" do
    @tag :e2e
    test "simple streaming request using openai_ex" do
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
      
      # Make streaming request using the OpenAI library
      IO.puts("\nMaking streaming request using openai_ex...")
      
      result = try do
        # Make the request with streaming enabled
        {:ok, response} = OpenaiEx.Chat.Completions.create(openai_client, chat_completion, stream: true)
        
        IO.puts("\nGot streaming response: #{inspect(response, pretty: true, limit: 1000)}")
        
        # Process the stream to collect content
        chunks = collect_stream_content(response)
        
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
  defp collect_stream_content(%{body_stream: body_stream}) do
    IO.puts("\nCollecting stream content...")
    
    result = body_stream
      |> Stream.flat_map(& &1)
      |> Stream.map(fn %{data: d} -> 
        # Debug print the data
        # IO.inspect(d, label: "Stream data")
        
        # Extract the delta content if present
        case d do
          %{"choices" => choices} when is_list(choices) and length(choices) > 0 ->
            choices
            |> List.first()
            |> Map.get("delta", %{})
            |> Map.get("content", "")
          _ -> ""
        end
      end)
      |> Stream.filter(fn content -> content != "" end)
      |> Enum.to_list()
    
    IO.puts("Collected #{length(result)} content chunks")
    result
  end
end