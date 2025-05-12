defmodule AI.ErrorTest do
  use ExUnit.Case

  alias AI.Error

  test "creates a basic error" do
    error = Error.new("An error occurred")
    assert error.message == "An error occurred"
    assert error.reason == nil
    assert error.source == nil
  end

  test "creates an error with a reason" do
    reason = {:timeout, 60_000}
    error = Error.new("Request timed out", reason)
    assert error.message == "Request timed out"
    assert error.reason == reason
    assert error.source == nil
  end

  test "creates an error with a reason and source" do
    reason = {:timeout, 60_000}
    error = Error.new("Request timed out", reason, __MODULE__)
    assert error.message == "Request timed out"
    assert error.reason == reason
    assert error.source == __MODULE__
  end

  test "wraps an existing error" do
    original_error = RuntimeError.exception("Something went wrong")
    error = Error.wrap(original_error, "Error during API call", __MODULE__)
    assert error.message == "Error during API call"
    assert error.reason == original_error
    assert error.source == __MODULE__
  end

  test "implements Exception behavior and can be raised and rescued" do
    error = Error.new("Something bad happened", {:bad_input, "Invalid argument"}, __MODULE__)

    assert_raise AI.Error, "Something bad happened", fn ->
      raise error
    end

    try do
      raise error
    rescue
      e in AI.Error ->
        # Verify we can access properties
        assert e.message == "Something bad happened"
        assert e.reason == {:bad_input, "Invalid argument"}
        assert e.source == __MODULE__
    end
  end

  test "converts standard exceptions to AI.Error" do
    # Simulate a standard error being raised and caught
    standard_error =
      try do
        # This will raise an ArgumentError
        raise ArgumentError, "Invalid argument provided"
      rescue
        e -> e
      end

    # Convert to our error format
    ai_error = Error.from_exception(standard_error, __MODULE__)

    # Verify the conversion
    assert %AI.Error{} = ai_error
    assert ai_error.message == "Invalid argument provided"
    assert ai_error.reason == standard_error
    assert ai_error.source == __MODULE__
  end
end
