defmodule Camarero.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    Application.ensure_all_started(:cowboy)

    # List all child processes to be supervised
    children = [
      Plug.Cowboy.child_spec(scheme: :http, plug: Camarero.Endpoint, options: [port: 4001])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Camarero.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
