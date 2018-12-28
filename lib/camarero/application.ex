defmodule Camarero.Application do
  @moduledoc false

  use Application

  @default_port 4001
  @default_scheme :http

  def start(_type, _args) do
    Application.ensure_all_started(:cowboy)

    catering = Application.get_env(:camarero, :catering, [])

    cowboy = Application.get_env(:camarero, :cowboy, [])

    options = [
      {:port, Keyword.get(cowboy, :port, @default_port)} | Keyword.get(cowboy, :options, [])
    ]

    # List all child processes to be supervised
    children = [
      Plug.Cowboy.child_spec(
        scheme: Keyword.get(cowboy, :scheme, @default_scheme),
        plug: Camarero.Endpoint,
        options: options
      ),
      {Camarero.Catering, [catering]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Camarero.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
