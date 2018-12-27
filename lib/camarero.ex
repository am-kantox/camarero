defmodule Camarero do
  @moduledoc false

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
