defmodule Camarero.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    catering = Application.get_env(:camarero, :catering, [])
    children = [{Camarero.Catering, [catering]}]

    opts = [strategy: :one_for_one, name: Camarero.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      for {runner, {Plug.Cowboy, cowboy}} <- Camarero.Catering.Routes.get("★") do
        IO.inspect(DynamicSupervisor.start_child(Camarero.Catering, {runner, []}), label: "☆☆☆")

        # IO.inspect(DynamicSupervisor.start_child(Camarero.Catering, {Plug.Cowboy, cowboy}),
        #   label: "★★★"
        # )

        # cowboy[:port])
        Plug.Cowboy.http(cowboy[:plug], [], port: 4002)
      end

      {:ok, pid}
    end
  end
end
