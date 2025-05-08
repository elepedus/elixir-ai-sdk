ExUnit.start()

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
