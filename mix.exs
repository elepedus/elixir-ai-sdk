defmodule AI.MixProject do
  use Mix.Project

  def project do
    [
      app: :ai_sdk,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "AI SDK",
      source_url: "https://github.com/yourusername/ai_sdk"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AI.Application, []}
    ]
  end

  defp deps do
    [
      {:tesla, "~> 1.7"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:finch, "~> 0.16"},
      {:mox, "~> 1.2", only: :test},
      {:openai_ex, "~> 0.9.7", only: :test}
    ]
  end

  defp description do
    """
    AI SDK for Elixir - A toolkit for building AI-powered applications in Elixir,
    inspired by Vercel's AI SDK.
    """
  end

  defp package do
    [
      name: :ai_sdk,
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/yourusername/ai_sdk"}
    ]
  end
end
