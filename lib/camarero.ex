defmodule Camarero do
  @moduledoc false

  # idea by Dave Thomas https://twitter.com/pragdave/status/1077775018942185472
  defmodule Handler do
    use Plug.Router
    plug(:match)

    get("/*path") do
      [path, query] =
        case path |> Enum.join("/") |> String.split("#", parts: 2) do
          [path] -> [path, "index"]
          [path, query] -> [path, query]
        end

      case Camarero.Catering.Routes.get(String.trim(path, "/")) do
        module when is_atom(module) ->
          send_resp(conn, 200, Jason.encode!(apply(module, :get, [query])))

        nil ->
          send_resp(conn, 404, "Not found")
      end
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
