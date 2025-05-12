defmodule AI.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: AI.Finch},
      AI.ProviderRegistry
    ]

    opts = [strategy: :one_for_one, name: AI.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
