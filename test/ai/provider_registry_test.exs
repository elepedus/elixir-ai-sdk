defmodule AI.ProviderRegistryTest do
  use ExUnit.Case

  setup do
    # Clear providers before each test to ensure isolation
    pid = Process.whereis(AI.ProviderRegistry)

    if pid && Process.alive?(pid) do
      :sys.replace_state(pid, fn _ -> %{providers: %{}} end)
    end

    :ok
  end

  # Test a basic process setup
  test "registry process is running" do
    # The registry should be started by the application
    registry_pid = Process.whereis(AI.ProviderRegistry)

    # Verify it's running
    assert registry_pid != nil
    assert Process.alive?(registry_pid)
  end

  test "registers a provider" do
    # Create a mock provider module
    defmodule TestProvider do
      def init(opts), do: {:ok, opts}
    end

    # Register the provider with an ID
    result = AI.ProviderRegistry.register("test_provider", TestProvider)

    # Verify registration was successful
    assert result == :ok
  end

  test "gets a registered provider" do
    # Create a mock provider module
    defmodule GetTestProvider do
      def init(opts), do: {:ok, opts}
    end

    # Register the provider
    AI.ProviderRegistry.register("get_test", GetTestProvider)

    # Get the provider
    result = AI.ProviderRegistry.get_provider("get_test")

    # Verify we got the correct provider
    assert match?({:ok, %{module: GetTestProvider}}, result)
  end

  test "gets a language model by model ID" do
    # Create a mock provider module that implements language model creation
    defmodule ModelProvider do
      def get_language_model(model_name, _opts) do
        {:ok, %{type: :language_model, name: model_name, provider: __MODULE__}}
      end
    end

    # Register the provider
    AI.ProviderRegistry.register("model_provider", ModelProvider)

    # Get a language model using provider:model notation
    result = AI.ProviderRegistry.get_language_model("model_provider:test-model")

    # Verify we got the correct language model from the right provider
    assert match?({:ok, %{name: "test-model", provider: ModelProvider}}, result)
  end

  test "handles invalid model ID format" do
    # Try to get a model with an invalid ID (missing provider prefix)
    result = AI.ProviderRegistry.get_language_model("invalid-model-id-without-prefix")

    # Verify we get the appropriate error
    assert match?({:error, {:invalid_model_id, _}}, result)
  end
end
