defmodule Camarero.MixProject do
  use Mix.Project

  @app :camarero
  @app_name "camarero"
  @version "0.10.0"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      xref: [exclude: []],
      description: description(),
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      dialyzer: [
        plt_file: {:no_warn, ".dialyzer/plts/dialyzer.plt"},
        plt_add_apps: [:envio],
        ignore_warnings: ".dialyzer/ignore.exs"
      ],
      releases: [
        camarero: [
          include_executables_for: [:unix],
          applications: [
            sasl: :permanent,
            logger: :permanent,
            cowboy: :permanent,
            runtime_tools: :permanent,
            observer_cli: :permanent
          ]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Camarero.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.8"},
      {:plug_cowboy, "~> 2.0"},
      {:jason, "~> 1.0"},
      {:envio, "~> 0.4", optional: true},
      {:cowboy, "~> 2.0"},
      {:stream_data, "~> 0.4", only: :test},
      {:observer_cli, "~> 1.5", only: [:dev, :test]},
      {:credo, "~> 1.0", only: [:dev, :ci]},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev, :ci], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp aliases do
    [
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.ci": [
        "format --check-formatted",
        "credo --strict",
        "dialyzer --halt-exit-status"
      ]
    ]
  end

  defp description do
    """
    The application-wide registry with handy helpers to ease dispatching.
    """
  end

  defp package do
    [
      name: @app,
      files: ~w|config lib mix.exs README.md|,
      maintainers: ["Aleksei Matiushkin"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/am-kantox/#{@app}",
        "Docs" => "https://hexdocs.pm/#{@app}"
      }
    ]
  end

  defp docs do
    [
      main: @app_name,
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/#{@app}",
      logo: "stuff/logo-48.png",
      source_url: "https://github.com/am-kantox/#{@app}",
      extras: [
        "stuff/#{@app_name}.md"
      ],
      groups_for_modules: [
        # Envio

        Behaviours: [
          Camarero.Tapas,
          Camarero.Plato
        ],
        "Internal Data": [
          Camarero.Catering.Routes
        ],
        "Default Implementations": [
          Camarero.Carta.Heartbeat
        ]
      ]
    ]
  end
end
