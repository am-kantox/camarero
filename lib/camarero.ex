defmodule Camarero do
  @moduledoc false

  require Plug.Router

  defmacro __using__(opts \\ []) do
    scaffold = Keyword.get(opts, :scaffold, :full)
    into = Keyword.get(opts, :into, {:%{}, [], []})

    [
      quote(location: :keep, do: @after_compile({Camarero, :handler!})),
      case scaffold do
        :full ->
          quote(
            # bind_quoted: [into: into],
            location: :keep,
            do: use(Camarero.Plato, into: unquote(into))
          )

        :access ->
          quote(
            # bind_quoted: [into: into],
            location: :keep,
            do: use(Camarero.Tapas, into: unquote(into))
          )

        :none ->
          []
      end
    ]
  end

  # idea by Dave Thomas https://twitter.com/pragdave/status/1077775018942185472
  def handler!(env, _bytecode) do
    if Code.ensure_compiled?(Camarero.Handler) do
      :code.purge(Camarero.Handler)
      :code.delete(Camarero.Handler)
    end

    IO.puts(Macro.to_string(Macro.expand(handler_ast(), env)))
    ast = handler_ast()

    # Macro.Env.location(env))
    Module.create(
      Camarero.Handler,
      quote(do: unquote(Macro.expand(ast, env))),
      Macro.Env.location(env)
    )
  end

  defp handler_ast() do
    root = ("/" <> (:camarero |> Application.get_env(:root, ""))) |> String.trim("/")

    {routes, ast} =
      :camarero
      |> Application.get_env(:carta, [])
      |> Enum.filter(&Code.ensure_compiled?/1)
      |> Enum.sort_by(&(&1 |> apply(:plato_route, []) |> String.length()), &<=/2)
      |> Enum.reduce(
        {[], []},
        fn module, {routes, ast} ->
          route = Enum.join([root, module |> apply(:plato_route, []) |> String.trim("/")], "/")

          {get_all, get_param} =
            {quote do
               get unquote(route) do
                 values = apply(unquote(module), :plato_all, [])

                 send_resp(
                   conn,
                   200,
                   Jason.encode!(%{key: "★", value: values})
                 )
               end
             end,
             quote do
               get unquote("#{route}/:param") do
                 response!(conn, unquote(module), param)
               end
             end}

          {[{route, module} | routes], [get_all, get_param | ast]}
        end
      )

    quote location: :keep do
      @moduledoc false

      use Plug.Router
      plug(:match)

      @root unquote(root)
      Module.register_attribute(__MODULE__, :routes, accumulate: true, persist: true)

      defp response!(conn, module, param) do
        {status, response} =
          case apply(module, :plato_get, [param]) do
            {:ok, value} -> {200, %{key: param, value: value}}
            :error -> {404, %{key: param, error: :not_found}}
            {:error, {status, cause}} -> {status, cause}
          end

        send_resp(conn, status, Jason.encode!(response))
      end

      def routes, do: unquote(routes)

      unquote_splicing(ast)

      get "#{@root}/*full_path1" do
        [param | path] = Enum.reverse(full_path1)
        path = path |> Enum.reverse() |> Enum.join("/")

        with {nil, _} <- {Camarero.Catering.Routes.get(path <> "/" <> param), ""},
             {nil, _} <- {Camarero.Catering.Routes.get(path), param} do
          send_resp(
            conn,
            400,
            Jason.encode!(%{
              error: "Handler was not found",
              path: Enum.join([@root | full_path1], "/")
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
  end

  defmodule Handler do
    use Plug.Router

    @root "/" <> (:camarero |> Application.get_env(:root, "") |> String.trim("/"))

    get("#{@root}/*full_path") do
      send_resp(
        conn,
        503,
        Jason.encode!(%{
          error: "Warming up...",
          path: Enum.join([@root | full_path], "/")
        })
      )
    end

    plug(:dispatch)
  end

  defmodule Endpoint do
    @moduledoc false

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
