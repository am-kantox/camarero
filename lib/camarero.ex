defmodule Camarero do
  @moduledoc false

  # idea by Dave Thomas https://twitter.com/pragdave/status/1077775018942185472
  defmodule Handler do
    use Plug.Router
    plug(:match)

    Module.register_attribute(__MODULE__, :routes, accumulate: true, persist: true)
    @root "/" <> (:camarero |> Application.get_env(:root, "") |> String.trim("/"))

    defp response!(conn, module, param) do
      {status, response} =
        case apply(module, :plato_get, [param]) do
          {:ok, value} -> {200, %{key: param, value: value}}
          :error -> {404, %{key: param, error: :not_found}}
          {:error, {status, cause}} -> {status, cause}
        end

      send_resp(conn, status, Jason.encode!(response))
    end

    Enum.each(
      :camarero
      |> Application.get_env(:carta, [])
      |> Enum.sort_by(&(&1 |> apply(:plato_route, []) |> String.length()), &>=/2),
      fn module ->
        route = Enum.join([@root, module |> apply(:plato_route, []) |> String.trim("/")], "/")
        @routes {route, module}

        get(route) do
          values = apply(unquote(module), :all, [])

          send_resp(
            conn,
            200,
            Jason.encode!(%{key: "★", value: values})
          )
        end

        get("#{route}/:param") do
          response!(conn, unquote(module), param)
        end
      end
    )

    def routes, do: @routes

    get("#{@root}/*full_path") do
      [param | path] = Enum.reverse(full_path)
      path = path |> Enum.reverse() |> Enum.join("/")

      with {nil, _} <- {Camarero.Catering.Routes.get(path <> "/" <> param), ""},
           {nil, _} <- {Camarero.Catering.Routes.get(path), param} do
        send_resp(
          conn,
          400,
          Jason.encode!(%{
            error: "Handler was not found",
            path: Enum.join([@root | full_path], "/")
          })
        )
      else
        {module, param} -> response!(conn, module, param)
      end
    end

    # . . .

    match(_) do
      send_resp(
        conn,
        400,
        Jason.encode!(%{error: "API root was not met", path: conn.request_path})
      )
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
