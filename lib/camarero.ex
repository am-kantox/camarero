defmodule Camarero do
  @moduledoc false

  # idea by Dave Thomas https://twitter.com/pragdave/status/1077775018942185472
  defmodule Handler do
    use Plug.Router
    plug(:match)

    Module.register_attribute(__MODULE__, :routes, accumulate: true, persist: true)

    Enum.each(
      Application.get_env(:camarero, :carta, %{}),
      fn module ->
        route = apply(module, :route, [])
        @routes {route, module}

        get(route) do
          send_resp(
            conn,
            200,
            Jason.encode!(apply(unquote(module), :get, [""]))
          )
        end

        get("/#{route}/:param") do
          send_resp(
            conn,
            200,
            Jason.encode!(apply(unquote(module), :get, [param]))
          )
        end
      end
    )

    def routes, do: @routes

    get("/*path") do
      [param | path] = Enum.reverse(path)
      path = path |> Enum.reverse() |> Enum.join("/")

      with {nil, _} <- {Camarero.Catering.Routes.get(path <> "/" <> param), ""},
           {nil, _} <- {Camarero.Catering.Routes.get(path), param} do
        send_resp(conn, 404, "Not found")
      else
        {module, param} ->
          send_resp(conn, 200, Jason.encode!(apply(module, :get, [param])))
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
