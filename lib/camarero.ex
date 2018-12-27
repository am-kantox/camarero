defmodule Camarero do
  @moduledoc false

  defmodule Cowboy do
    use Supervisor

    @doc """
    Starts a new cowboy web server.
    """
    def start_link(args \\ []) do
      Supervisor.start_link(__MODULE__, args, name: __MODULE__)
    end

    @impl true
    def init(_arg) do
      settings = Application.get_env(:camarero, :cowboy, [])
      port = Keyword.get(settings, :port, 8080)

      env =
        settings
        |> Keyword.get(:env, [])
        |> Enum.into(%{})

      children = [
        %{
          id: Camarero.Cowboy,
          start: {:cowboy, :start_clear, [:camarero, [port: port], %{env: env}]}
        }
      ]

      Supervisor.init(children, strategy: :one_for_one)
    end
  end

  # idea by Dave Thomas https://twitter.com/pragdave/status/1077775018942185472
  defmodule Handler do
    use Plug.Router
    plug(:match)

    get("/login/:id") do
      send_resp(conn, 200, "You said #{inspect(conn.params)}")
    end

    # . . .

    match(_) do
      send_resp(conn, 404, "Not found")
    end

    plug(:dispatch)
  end

  defmodule Endpoint do
    use Plug.Builder
    plug(Plug.Logger)

    plug(Plug.Parsers,
      parsers: [:json],
      pass: ["application/json"],
      json_decoder: Jason
    )

    plug(Camarero.Handler)
  end
end
