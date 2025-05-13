defmodule AI.StreamingImplementationsComparisonTest do
  use ExUnit.Case

  # This test requires an actual OpenAI API key
  # It's tagged as e2e and will be skipped unless explicitly included
  @moduletag :e2e

  @api_key System.get_env("OPENAI_API_KEY")

  # Fixed seed value for deterministic output
  @seed 12345

  # Shared test prompt
  @prompt "Explain the blue sky phenomenon in one sentence."
  @model "gpt-4o-mini"
  # Using 0 temperature for more deterministic output
  @temperature 0.0
  @max_tokens 100

  describe "openai_ex vs ai_sdk streaming implementations" do
    @tag :e2e
    test "compare outputs from openai_ex streaming and AI.stream_text" do
      IO.puts("\n==== COMPARISON OF STREAMING IMPLEMENTATIONS ====\n")
      IO.puts("Using fixed seed: #{@seed}")
      IO.puts("Using prompt: \"#{@prompt}\"")
      IO.puts("Using model: #{@model}")
      IO.puts("Using temperature: #{@temperature}\n")

      # Run both implementations and collect results
      {openai_ex_content, openai_ex_chunks} = run_openai_ex_streaming()
      {ai_sdk_content, ai_sdk_chunks} = run_ai_sdk_streaming()

      # Compare the results
      IO.puts("\n==== RESULTS ====\n")
      IO.puts("OpenAI Ex content (#{length(openai_ex_chunks)} chunks): #{openai_ex_content}")
      IO.puts("AI SDK content (#{length(ai_sdk_chunks)} chunks): #{ai_sdk_content}")

      # Check if the complete responses are identical
      are_identical = openai_ex_content == ai_sdk_content

      IO.puts("\nComplete responses identical? #{are_identical}")

      if not are_identical do
        IO.puts("\nDifferences in output:")

        # Use String.myers_difference to show differences
        differences = String.myers_difference(openai_ex_content, ai_sdk_content)
        IO.inspect(differences, label: "Output differences")
      end

      # Optional: Check similarity even if they're not identical
      similarity_ratio =
        if openai_ex_content != "" and ai_sdk_content != "" do
          # Calculate Levenshtein distance
          distance = calculate_levenshtein_distance(openai_ex_content, ai_sdk_content)
          max_length = max(String.length(openai_ex_content), String.length(ai_sdk_content))
          similarity = 1 - distance / max_length
          Float.round(similarity * 100, 2)
        else
          0.0
        end

      IO.puts("\nSimilarity ratio: #{similarity_ratio}%")

      # Analyze the differences in chunk patterns
      analyze_chunk_patterns(openai_ex_chunks, ai_sdk_chunks)

      # Assertions - both implementations should work and produce similar results
      assert openai_ex_content != ""
      assert ai_sdk_content != ""
      assert similarity_ratio > 90.0, "Outputs should be at least 90% similar"
    end
  end

  # Run the openai_ex streaming implementation
  defp run_openai_ex_streaming do
    IO.puts("\n---- Running OpenAI Ex streaming implementation ----\n")

    # Create the OpenAI client
    openai_client = OpenaiEx.new(@api_key)

    # Create the messages
    messages = [
      OpenaiEx.ChatMessage.system("You are a helpful, concise assistant."),
      OpenaiEx.ChatMessage.user(@prompt)
    ]

    # Create chat completion request with seed
    chat_completion =
      OpenaiEx.Chat.Completions.new(
        model: @model,
        messages: messages,
        max_tokens: @max_tokens,
        temperature: @temperature,
        seed: @seed
      )

    # Make streaming request
    {content, chunks} =
      try do
        {:ok, response} =
          OpenaiEx.Chat.Completions.create(openai_client, chat_completion, stream: true)

        # Process the stream
        chunks = collect_openai_ex_stream_content(response)

        # Extract full content
        content =
          chunks
          |> Enum.join("")

        {content, chunks}
      rescue
        e ->
          IO.puts("Error with OpenAI Ex streaming: #{inspect(e)}")
          {"", []}
      end

    {content, chunks}
  end

  # Run the AI.stream_text implementation
  defp run_ai_sdk_streaming do
    IO.puts("\n---- Running AI SDK streaming implementation ----\n")

    # Create OpenAI model
    model = AI.openai(@model, api_key: @api_key)

    {content, chunks} =
      try do
        # Make the streaming request
        {:ok, response} =
          AI.stream_text(%{
            model: model,
            system: "You are a helpful, concise assistant.",
            prompt: @prompt,
            max_tokens: @max_tokens,
            temperature: @temperature,
            seed: @seed
          })

        # Process the stream
        chunks = collect_ai_sdk_stream_content(response.stream)

        # Extract full content
        content =
          chunks
          |> Enum.filter(fn
            {:text_delta, _} -> true
            _ -> false
          end)
          |> Enum.map(fn {:text_delta, text} -> text end)
          |> Enum.join("")

        {content, chunks}
      rescue
        e ->
          IO.puts("Error with AI SDK streaming: #{inspect(e)}")
          {"", []}
      end

    {content, chunks}
  end

  # Helper to collect content from openai_ex stream
  defp collect_openai_ex_stream_content(%{body_stream: body_stream}) do
    body_stream
    |> Stream.flat_map(& &1)
    |> Stream.map(fn %{data: d} ->
      case d do
        %{"choices" => choices} when is_list(choices) and length(choices) > 0 ->
          choices
          |> List.first()
          |> Map.get("delta", %{})
          |> Map.get("content", "")

        _ ->
          ""
      end
    end)
    |> Stream.filter(fn content -> content != "" end)
    |> Enum.to_list()
  end

  # Helper to collect content from AI.stream_text stream
  defp collect_ai_sdk_stream_content(stream) do
    Enum.reduce_while(stream, [], fn
      # Text delta events
      {:text_delta, chunk} = event, acc ->
        IO.write(chunk)
        {:cont, [event | acc]}

      # Finish events
      {:finish, reason} = event, acc ->
        IO.puts("\nFinished: #{reason}")
        {:halt, [event | acc]}

      # Error events
      {:error, error} = event, acc ->
        IO.puts("\nError: #{inspect(error)}")
        {:halt, [event | acc]}

      # Other events
      other, acc ->
        {:cont, [other | acc]}
    end)
    |> Enum.reverse()
  end

  # Analyze the patterns in how chunks are split between implementations
  defp analyze_chunk_patterns(openai_ex_chunks, ai_sdk_chunks) do
    IO.puts("\n==== CHUNK PATTERN ANALYSIS ====\n")

    # Filter only text chunks from AI SDK
    ai_sdk_text_chunks =
      ai_sdk_chunks
      |> Enum.filter(fn
        {:text_delta, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {:text_delta, text} -> text end)

    # Count chunks
    openai_ex_chunk_count = length(openai_ex_chunks)
    ai_sdk_chunk_count = length(ai_sdk_text_chunks)

    IO.puts("OpenAI Ex chunk count: #{openai_ex_chunk_count}")
    IO.puts("AI SDK text chunk count: #{ai_sdk_chunk_count}")

    # Average chunk sizes
    openai_ex_avg_size =
      if openai_ex_chunk_count > 0 do
        total_size = openai_ex_chunks |> Enum.map(&String.length/1) |> Enum.sum()
        Float.round(total_size / openai_ex_chunk_count, 2)
      else
        0.0
      end

    ai_sdk_avg_size =
      if ai_sdk_chunk_count > 0 do
        total_size = ai_sdk_text_chunks |> Enum.map(&String.length/1) |> Enum.sum()
        Float.round(total_size / ai_sdk_chunk_count, 2)
      else
        0.0
      end

    IO.puts("OpenAI Ex average chunk size: #{openai_ex_avg_size} characters")
    IO.puts("AI SDK average chunk size: #{ai_sdk_avg_size} characters")

    # Show chunk samples if available
    if openai_ex_chunk_count > 0 do
      sample_count = min(5, openai_ex_chunk_count)
      IO.puts("\nOpenAI Ex first #{sample_count} chunks:")

      openai_ex_chunks
      |> Enum.take(sample_count)
      |> Enum.with_index(1)
      |> Enum.each(fn {chunk, i} ->
        IO.puts("  #{i}. \"#{chunk}\" (#{String.length(chunk)} chars)")
      end)
    end

    if ai_sdk_chunk_count > 0 do
      sample_count = min(5, ai_sdk_chunk_count)
      IO.puts("\nAI SDK first #{sample_count} chunks:")

      ai_sdk_text_chunks
      |> Enum.take(sample_count)
      |> Enum.with_index(1)
      |> Enum.each(fn {chunk, i} ->
        IO.puts("  #{i}. \"#{chunk}\" (#{String.length(chunk)} chars)")
      end)
    end
  end

  # Levenshtein distance calculation for measuring string similarity
  defp calculate_levenshtein_distance(s, t) do
    # Handle edge cases
    cond do
      s == t ->
        0

      String.length(s) == 0 ->
        String.length(t)

      String.length(t) == 0 ->
        String.length(s)

      true ->
        # Convert strings to character lists
        s_chars = String.graphemes(s)
        t_chars = String.graphemes(t)

        # Initialize matrix
        matrix = initialize_matrix(s_chars, t_chars)

        # Fill matrix
        fill_matrix(matrix, s_chars, t_chars)
        |> get_distance(String.length(s), String.length(t))
    end
  end

  defp initialize_matrix(s_chars, t_chars) do
    # Create a map with keys as {row, col} tuples
    s_len = length(s_chars)
    t_len = length(t_chars)

    # Initialize first row
    row0 =
      Enum.reduce(0..t_len, %{}, fn j, acc ->
        Map.put(acc, {0, j}, j)
      end)

    # Initialize first column
    Enum.reduce(1..s_len, row0, fn i, acc ->
      Map.put(acc, {i, 0}, i)
    end)
  end

  defp fill_matrix(matrix, s_chars, t_chars) do
    s_len = length(s_chars)
    t_len = length(t_chars)

    # Iterate through all cells
    Enum.reduce(1..s_len, matrix, fn i, acc1 ->
      Enum.reduce(1..t_len, acc1, fn j, acc2 ->
        cost = if Enum.at(s_chars, i - 1) == Enum.at(t_chars, j - 1), do: 0, else: 1

        deletion = Map.get(acc2, {i - 1, j}) + 1
        insertion = Map.get(acc2, {i, j - 1}) + 1
        substitution = Map.get(acc2, {i - 1, j - 1}) + cost

        Map.put(acc2, {i, j}, Enum.min([deletion, insertion, substitution]))
      end)
    end)
  end

  defp get_distance(matrix, i, j) do
    Map.get(matrix, {i, j})
  end
end
