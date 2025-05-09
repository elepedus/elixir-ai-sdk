# Read command line args for detecting e2e tests 
args = System.argv()
e2e_file = args |> Enum.any?(&String.contains?(&1, "e2e_test"))
include_flag_index = Enum.find_index(args, &(&1 == "--include"))
e2e_tag = if include_flag_index, do: Enum.at(args, include_flag_index + 1) == "e2e", else: false
e2e_tests = e2e_file || e2e_tag

# Configure ExUnit based on the presence of e2e tests
if e2e_tests do
  # For e2e tests, include e2e tests explicitly
  ExUnit.configure(include: [e2e: true])
else
  # For regular tests, exclude e2e tests
  ExUnit.configure(exclude: [e2e: true])
end

# Start ExUnit
ExUnit.start()

# Only log e2e testing mode when explicitly requested
if e2e_tests or System.get_env("DEBUG") do
  IO.puts("E2E testing mode: #{e2e_tests}")
end

# Skip mock setup for e2e tests
unless e2e_tests do
  # Define mocks for Tesla
  Mox.defmock(Tesla.MockAdapter, for: Tesla.Adapter)
  Application.put_env(:tesla, :adapter, Tesla.MockAdapter)
  
  # Define a behaviour for EventSource using the real module's spec
  defmodule AI.Provider.Utils.EventSourceBehaviour do
    @callback post(String.t(), map(), map(), map()) ::
      {:ok, %{status: integer(), body: binary(), stream: Stream.t() | list()}} |
      {:error, term()}
  end
  
  # Define the mock for EventSource - all tests should use this same mock
  Mox.defmock(AI.Provider.Utils.EventSourceMock, for: AI.Provider.Utils.EventSourceBehaviour)
  
  # We don't want to stub by default since we'll set expectations in each test
end
