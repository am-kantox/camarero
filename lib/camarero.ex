defmodule Camarero do
  @moduledoc "README.md" |> File.read!() |> String.split("\n") |> Enum.drop(2) |> Enum.join("\n")

  require Plug.Router
  require Logger
  alias Camarero.Catering.Routes

  @allowed_methods ~w|get post put delete|a

  defmacro __using__(opts \\ []) do
    env = __CALLER__
    into = Keyword.get(opts, :into, {:%{}, [], []})
    response_as = Keyword.get(opts, :response_as, :map)
    scaffold = Keyword.get(opts, :scaffold, :full)

    methods =
      opts[:methods]
      |> Macro.expand(__CALLER__)
      |> case do
        nil -> [:get]
        method when method in @allowed_methods -> [method]
        list when is_list(list) -> list
      end
      |> Enum.map(&(&1 |> to_string() |> String.downcase() |> String.to_existing_atom()))
      |> Enum.filter(&(&1 in @allowed_methods))

    [
      quote(generated: true, do: @compile({:autoload, true})),
      quote(generated: true, do: @after_compile({Camarero, :handler!})),
      quote(
        generated: true,
        location: :keep,
        do:
          @handler_fq_name(
            Keyword.get(
              unquote(opts),
              :as,
              Module.concat([__MODULE__, "Camarero"])
            )
          )
      ),
      quote(
        generated: true,
        location: :keep,
        do:
          defstruct(
            handler_fq_name: @handler_fq_name,
            methods: unquote(methods),
            response_as: unquote(response_as),
            scaffold: unquote(scaffold),
            __env__: unquote(Macro.escape(env))
          )
      ),
      case scaffold do
        :full ->
          quote(
            generated: true,
            location: :keep,
            do: use(Camarero.Plato, into: unquote(into))
          )

        :access ->
          quote(
            generated: true,
            location: :keep,
            do: use(Camarero.Tapas, into: unquote(into))
          )

        :none ->
          []
      end
    ]
  end

  # idea by Dave Thomas https://twitter.com/pragdave/status/1077775018942185472
  @doc false
  @spec handler!(env :: nil | Macro.Env.t(), _bytecode :: nil | binary()) :: {atom(), atom()}
  def handler!(env, _bytecode) do
    fq_name = struct(env.module).handler_fq_name

    handler_name = Module.concat(fq_name, Handler)
    endpoint_name = Module.concat(fq_name, Endpoint)

    # ? FIXME THIS IS AN UGLY HACK UNTIL I WILL FIND THE PROPER SOLUTION
    #! <UGLY HACK>
    Code.compiler_options(ignore_module_conflict: true)
    rehandler!(handler_name, endpoint_name, env)
    Code.compiler_options(ignore_module_conflict: false)

    #! </UGLY HACK>

    {handler_name, endpoint_name}
  end

  defp rehandler!(handler_name, endpoint_name, env) do
    handler_ast = handler_ast()
    remodule!(handler_name, handler_ast, env)

    unless match?({:module, ^handler_name}, Code.ensure_compiled(handler_name)),
      do: raise(CompileError, message: "Generator conflict")

    endpoint_ast = endpoint_ast(handler_name)
    remodule!(endpoint_name, endpoint_ast, env)

    Logger.info("[🕷️] handler and endpoint created successfully",
      handler: handler_name,
      endpoint: endpoint_name
    )
  rescue
    err in [CompileError, UndefinedFunctionError] ->
      waiting = round(:rand.uniform() * 100)

      Logger.debug(fn ->
        "Deferring creation of #{env.module} for #{waiting} ms (#{inspect(err)})" <>
          inspect(__STACKTRACE__)
      end)

      Process.sleep(waiting)
      rehandler!(handler_name, endpoint_name, env)
  end

  @spec remodule!(atom(), any(), %Macro.Env{}) :: {:module, module(), binary(), term()}
  defp remodule!(name, ast, env) do
    if match?({:module, ^name}, Code.ensure_compiled(name)) do
      :code.purge(name)
      :code.delete(name)
    end

    Module.create(
      name,
      quote(generated: true, do: unquote(Macro.expand(ast, env))),
      Macro.Env.location(env)
    )
  end

  @spec handler_wrapper(method :: atom(), endpoint :: binary(), block :: any()) :: any()
  defp handler_wrapper(method, endpoint, block) when method in @allowed_methods do
    path = endpoint
    route = Plug.Router.__route__(method, path, true, [])
    {conn, method, match, params, _host, guards, private, assigns} = route

    quote generated: true do
      defp(
        do_match(unquote(conn), unquote(method), unquote(match), _)
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

        Plug.Router.__put_route__(conn, unquote(path), fn conn, opts -> unquote(block) end)
      end
    end
  end

  # credo:disable-for-lines:160
  @spec handler_ast() :: term()
  defp handler_ast() do
    root = ("/" <> (:camarero |> Application.get_env(:root, ""))) |> String.trim("/")

    items =
      if Enum.find(Process.registered(), &(&1 == Routes)) do
        Map.values(Routes.state())
      else
        Application.get_env(:camarero, :carta, [])
      end

    send_resp_block =
      quote generated: true do
        defp send_resp_and_envio(conn, status, what) do
          Camarero.Spitter.spit(:all, %{conn: conn, status: status, what: what})

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(status, what)
        end
      end

    {routes, ast} =
      items
      |> Enum.filter(&match?(mod when is_atom(mod), &1))
      |> Enum.filter(&match?({:module, ^&1}, Code.ensure_compiled(&1)))
      |> Enum.sort_by(&(&1 |> apply(:plato_route, []) |> String.length()), &<=/2)
      |> Enum.reduce(
        {[], []},
        fn module, {routes, ast} ->
          endpoint = Enum.join([root, module |> apply(:plato_route, []) |> String.trim("/")], "/")

          {routes, ast} =
            if Enum.find(struct(module).methods, &(&1 == :get)) do
              get_all_block =
                quote generated: true do
                  {values, status} =
                    case apply(unquote(module), :plato_all, []) do
                      {values, status} -> {values, status}
                      values -> {values, 200}
                    end

                  send_resp_and_envio(
                    conn,
                    status,
                    Jason.encode!(
                      case struct(unquote(module)).response_as do
                        :value -> values
                        :map -> %{key: "★", value: values}
                        _ -> values
                      end
                    )
                  )
                end

              get_all = handler_wrapper(:get, endpoint, get_all_block)

              param = Macro.var(:param, nil)

              get_param_block =
                quote(generated: true, do: response!(conn, unquote(module), unquote(param)))

              get_param =
                handler_wrapper(:get, Enum.join([endpoint, ":param"], "/"), get_param_block)

              {[{:get, endpoint, module} | routes], [get_all, get_param | ast]}
            else
              {routes, ast}
            end

          {routes, ast} =
            if Enum.find(struct(module).methods, &(&1 == :post)) do
              post_block =
                quote generated: true do
                  case apply(unquote(module), :reshape, [conn.params]) do
                    %{"key" => key, "value" => value} ->
                      {value, status} =
                        case apply(unquote(module), :plato_put, [key, value]) do
                          {value, status} -> {value, status}
                          :ok -> {"", 201}
                          value -> {value, 201}
                        end

                      send_resp_and_envio(conn, status, value)

                    payload ->
                      send_resp_and_envio(
                        conn,
                        412,
                        Jason.encode!(
                          %{
                            errors: ["JSON object with both “key” and “value” keys is required"],
                            payload: payload
                          },
                          []
                        )
                      )
                  end
                end

              post_all = handler_wrapper(:post, endpoint, post_block)

              {[{:post, endpoint, module} | routes], [post_all | ast]}
            else
              {routes, ast}
            end

          {routes, ast} =
            if Enum.find(struct(module).methods, &(&1 == :put)) do
              put_block =
                quote generated: true do
                  case apply(unquote(module), :reshape, [conn.params]) do
                    %{"param" => key, "value" => value} ->
                      {value, status} =
                        case apply(unquote(module), :plato_put, [key, value]) do
                          {value, status} -> {value, status}
                          :ok -> {"", 200}
                          value -> {value, 200}
                        end

                      send_resp_and_envio(conn, status, value)

                    payload ->
                      send_resp_and_envio(
                        conn,
                        412,
                        Jason.encode!(
                          %{
                            errors: ["JSON object with “value” key is required"],
                            payload: payload
                          },
                          []
                        )
                      )
                  end
                end

              put_param = handler_wrapper(:put, Enum.join([endpoint, ":param"], "/"), put_block)

              {[{:put, endpoint, module} | routes], [put_param | ast]}
            else
              {routes, ast}
            end

          {routes, ast} =
            if Enum.find(struct(module).methods, &(&1 == :delete)) do
              delete_param_block =
                quote generated: true do
                  case apply(unquote(module), :reshape, [conn.params]) do
                    %{"param" => key} ->
                      {value, status} =
                        case apply(unquote(module), :plato_delete, [key]) do
                          {value, status} -> {value, status}
                          nil -> {:not_found, 404}
                          value -> {value, 200}
                        end

                      send_resp_and_envio(
                        conn,
                        status,
                        Jason.encode!(%{key: key, value: value})
                      )

                    other ->
                      send_resp_and_envio(
                        conn,
                        503,
                        Jason.encode!(%{
                          errors: ["You’ve found a bug; please report it :)"],
                          unexpected_value: inspect(other)
                        })
                      )
                  end
                end

              delete_param =
                handler_wrapper(:delete, Enum.join([endpoint, ":param"], "/"), delete_param_block)

              {[{:delete, endpoint, module} | routes], [delete_param | ast]}
            else
              {routes, ast}
            end

          {routes, ast}
        end
      )

    full_path = Macro.var(:full_path, nil)

    catch_all_block =
      quote generated: true do
        [param | path] = Enum.reverse(unquote(full_path))
        path = path |> Enum.reverse() |> Enum.join("/")

        with {nil, _} <- {Routes.get(path <> "/" <> param), ""},
             {nil, _} <- {Routes.get(path), param} do
          send_resp_and_envio(
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

    catch_dynamic = handler_wrapper(:get, Enum.join([root, "*full_path"], "/"), catch_all_block)
    catch_all = Enum.map(@allowed_methods, &handler_wrapper(&1, "/*full_path", catch_all_block))

    quote generated: true, location: :keep do
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

        send_resp_and_envio(conn, status, Jason.encode!(response))
      end

      def routes, do: unquote(Macro.escape(routes))

      unquote(send_resp_block)
      unquote_splicing(Enum.reverse(catch_all ++ [catch_dynamic | ast]))

      plug(:dispatch)
    end
  end

  defp endpoint_ast(handler) do
    quote generated: true do
      @moduledoc false

      use Plug.Builder, init_mode: :runtime
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
