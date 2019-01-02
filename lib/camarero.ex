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

    ast = handler_ast()
    IO.puts(Macro.to_string(Macro.expand(ast, env)))

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
          endpoint = Enum.join([root, module |> apply(:plato_route, []) |> String.trim("/")], "/")

          path = endpoint
          route = Plug.Router.__route__(:get, path, true, [])
          {conn, method, match, params, host, guards, private, assigns} = route

          get_all_block =
            quote do
              values = apply(unquote(module), :plato_all, [])

              send_resp(
                conn,
                200,
                Jason.encode!(%{key: "★", value: values})
              )
            end

          get_all =
            quote do
              defp(
                do_match(unquote(conn), unquote(method), unquote(match), unquote(host))
                when unquote(guards)
              ) do
                unquote(private)
                unquote(assigns)

                merge_params = fn
                  %Plug.Conn.Unfetched{} ->
                    unquote({:%{}, [], params})

                  fetched ->
                    Map.merge(fetched, unquote({:%{}, [], params}))
                end

                conn = update_in(unquote(conn).params(), merge_params)
                conn = update_in(conn.path_params(), merge_params)

                Plug.Router.__put_route__(conn, unquote(path), fn var!(conn) ->
                  unquote(get_all_block)
                end)
              end
            end

          param = Macro.var(:param, nil)

          path = Enum.join([endpoint, ":param"], "/")
          route = Plug.Router.__route__(:get, path, true, [])
          {conn, method, match, params, host, guards, private, assigns} = route

          get_param_block = quote(do: response!(conn, unquote(module), unquote(param)))

          get_param =
            quote do
              defp(
                do_match(unquote(conn), unquote(method), unquote(match), unquote(host))
                when unquote(guards)
              ) do
                unquote(private)
                unquote(assigns)

                merge_params = fn
                  %Plug.Conn.Unfetched{} ->
                    unquote({:%{}, [], params})

                  fetched ->
                    Map.merge(fetched, unquote({:%{}, [], params}))
                end

                conn = update_in(unquote(conn).params(), merge_params)
                conn = update_in(conn.path_params(), merge_params)

                Plug.Router.__put_route__(conn, unquote(path), fn var!(conn) ->
                  unquote(get_param_block)
                end)
              end
            end

          {[{endpoint, module} | routes], [get_all, get_param | ast]}
        end
      )

    full_path = Macro.var(:full_path, nil)

    catch_all_block =
      quote do
        [param | path] = Enum.reverse(unquote(full_path))
        path = path |> Enum.reverse() |> Enum.join("/")

        with {nil, _} <- {Camarero.Catering.Routes.get(path <> "/" <> param), ""},
             {nil, _} <- {Camarero.Catering.Routes.get(path), param} do
          send_resp(
            conn,
            400,
            Jason.encode!(%{
              error: "Handler was not found",
              path: Enum.join([unquote(root) | unquote(full_path)], "/")
            })
          )
        else
          {module, param} -> response!(conn, module, param)
        end
      end

    path = Enum.join([root, "*full_path"], "/")
    route = Plug.Router.__route__(:get, path, true, [])
    {conn, method, match, params, host, guards, private, assigns} = route

    catch_all =
      quote do
        defp(
          do_match(unquote(conn), unquote(method), unquote(match), unquote(host))
          when unquote(guards)
        ) do
          unquote(private)
          unquote(assigns)

          merge_params = fn
            %Plug.Conn.Unfetched{} ->
              unquote({:%{}, [], params})

            fetched ->
              Map.merge(fetched, unquote({:%{}, [], params}))
          end

          conn = update_in(unquote(conn).params(), merge_params)
          conn = update_in(conn.path_params(), merge_params)

          Plug.Router.__put_route__(conn, unquote(path), fn var!(conn) ->
            unquote(catch_all_block)
          end)
        end
      end

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
      unquote_splicing([catch_all])

      # . . .
      # match(_) do
      #   send_resp(
      #     conn,
      #     400,
      #     Jason.encode!(%{error: "API root was not met", path: conn.request_path})
      #   )
      # end

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
