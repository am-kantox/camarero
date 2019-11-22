defmodule Camarero.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    catering = Application.get_env(:camarero, :catering, [])
    children = [{Camarero.Catering, [catering]}]

    opts = [strategy: :one_for_one, name: Camarero.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
