defmodule Camarero do
  @moduledoc false

  require Plug.Router

  defmacro __using__(opts \\ []) do
    scaffold = Keyword.get(opts, :scaffold, :full)
    response_as = Keyword.get(opts, :response_as, :map)
    into = Keyword.get(opts, :into, {:%{}, [], []})
    env = __CALLER__

    [
      quote(location: :keep, do: @after_compile({Camarero, :handler!})),
      quote(
        location: :keep,
        do:
          @handler_fq_name(
            Keyword.get(
              unquote(opts),
              :as,
              Module.concat(__MODULE__ |> Module.split() |> hd(), "Camarero")
            )
          )
      ),
      quote(
        location: :keep,
        do:
          defstruct(
            handler_fq_name: @handler_fq_name,
            response_as: unquote(response_as),
            scaffold: unquote(scaffold),
            __env__: unquote(Macro.escape(env))
          )
      ),
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
  @spec handler!(env :: nil | %Macro.Env{}, _bytecode :: binary()) :: {atom(), atom()}
  def handler!(env, _bytecode) do
    fq_name = struct(env.module).handler_fq_name

    handler_name = Module.concat(fq_name, Handler)
    endpoint_name = Module.concat(fq_name, Endpoint)

    endpoints =
      [endpoint_name | Application.get_env(:camarero, :endpoints, [])]
      |> MapSet.new()
      |> MapSet.to_list()

    Application.put_env(:camarero, :endpoints, endpoints, persistent: true)
    handler_ast = handler_ast()
    remodule!(handler_name, handler_ast, env)

    endpoint_ast = endpoint_ast(handler_name)
    remodule!(endpoint_name, endpoint_ast, env)

    {handler_name, endpoint_name}
  end

  @spec remodule!(atom(), any(), %Macro.Env{}) :: {:module, module(), binary(), term()}
  defp remodule!(name, ast, env) do
    if Code.ensure_compiled?(name) do
      :code.purge(name)
      :code.delete(name)
    end

    Module.create(
      name,
      quote(do: unquote(Macro.expand(ast, env))),
      Macro.Env.location(env)
    )
  end

  @spec handler_wrapper(endpoint :: binary(), block :: any()) :: any()
  defp handler_wrapper(endpoint, block) do
    path = endpoint
    route = Plug.Router.__route__(:get, path, true, [])
    {conn, method, match, params, host, guards, private, assigns} = route

    quote do
      defp(
        do_match(unquote(conn), unquote(method), unquote(match), unquote(host))
        when unquote(guards)
      ) do
        unquote(private)
        unquote(assigns)

        merge_params = fn
          %Plug.Conn.Unfetched{} -> unquote({:%{}, [], params})
          fetched -> Map.merge(fetched, unquote({:%{}, [], params}))
        end

        conn = update_in(unquote(conn).params(), merge_params)
        conn = update_in(conn.path_params(), merge_params)

        Plug.Router.__put_route__(conn, unquote(path), fn conn -> unquote(block) end)
      end
    end
  end

  @spec handler_ast() :: term()
  defp handler_ast() do
    root = ("/" <> (:camarero |> Application.get_env(:root, ""))) |> String.trim("/")

    items =
      if Enum.find(Process.registered(), &(&1 == Camarero.Catering.Routes)) do
        Map.values(Camarero.Catering.Routes.state())
      else
        Application.get_env(:camarero, :carta, [])
      end

    {routes, ast} =
      items
      |> Enum.filter(&Code.ensure_compiled?/1)
      |> Enum.sort_by(&(&1 |> apply(:plato_route, []) |> String.length()), &<=/2)
      |> Enum.reduce(
        {[], []},
        fn module, {routes, ast} ->
          endpoint = Enum.join([root, module |> apply(:plato_route, []) |> String.trim("/")], "/")

          get_all_block =
            quote do
              values = apply(unquote(module), :plato_all, [])

              send_resp(
                conn,
                200,
                Jason.encode!(%{key: "★", value: values})
              )
            end

          get_all = handler_wrapper(endpoint, get_all_block)

          param = Macro.var(:param, nil)
          get_param_block = quote(do: response!(conn, unquote(module), unquote(param)))
          get_param = handler_wrapper(Enum.join([endpoint, ":param"], "/"), get_param_block)

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
          {module, param} ->
            Logger.warn(fn ->
              ~s|Accessing “#{Enum.join(unquote(full_path), "/")}” dynamically. Consider compiling routes.|
            end)

            response!(conn, module, param)
        end
      end

    catch_dynamic = handler_wrapper(Enum.join([root, "*full_path"], "/"), catch_all_block)
    catch_all = handler_wrapper("/*full_path", catch_all_block)

    quote location: :keep do
      @moduledoc false

      require Logger

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

        response =
          case struct(module).response_as do
            :map ->
              response

            :value ->
              with %{} <- response,
                   [{_, _}, {_, value}] <- Map.to_list(response),
                   do: value

            _ ->
              response
          end

        send_resp(conn, status, Jason.encode!(response))
      end

      def routes, do: unquote(routes)

      unquote_splicing(Enum.reverse([catch_all, catch_dynamic | ast]))

      plug(:dispatch)
    end
  end

  defp endpoint_ast(handler) do
    quote do
      @moduledoc false

      use Plug.Builder
      plug(Plug.Logger)

      plug(Plug.Parsers,
        parsers: [:json],
        pass: ["application/json"],
        json_decoder: Jason
      )

      plug(unquote(handler))
    end
  end
end
