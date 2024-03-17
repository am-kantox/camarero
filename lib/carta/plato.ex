defmodule Camarero.Plato do
  @moduledoc """
  This behaviour is high-level abstraction of the container begind handlers.

  All handlers are supposed to implement this behaviour. The simplest way
  is to `use Camarero.Plato` in the handler module; that will inject
  the default boilerlate using `%{binary() => any()}` map as a container behind.

  Default implementation uses `Camarero.Tapas` as low-level container implementation.
  """

  @typedoc "HTTP status code"
  @type status_code :: non_neg_integer()

  @doc "Returns the container itself, as is"
  @callback plato_all() :: Camarero.Tapas.t()
  @doc "Returns the value for the key specified"
  @callback plato_get(key :: binary() | atom()) ::
              {:ok, any()} | :error | {:error, {status_code(), map()}}
  @doc "Sets the value for the key specified (intended to be used from the application)"
  @callback plato_put(key :: binary() | atom(), value :: any()) ::
              :ok | {binary(), status_code()} | binary()
  @doc "Deletes the key-value pair for the key specified"
  @callback plato_delete(key :: binary() | atom()) ::
              nil | {binary(), status_code()} | binary()
  @doc "Returns the route this module is supposed to be mounted to"
  @callback plato_route() :: binary()
  @doc "Returns the key-value map out of a random input"
  @callback reshape(map()) :: map()
  @doc "Returns the key-value map out of a random input, the second argument contains additional request data"
  @callback reshape(map(), keyword()) :: map()

  @doc false
  defmacro __using__(opts \\ []) do
    {into, opts} = Keyword.pop(opts, :into, {:%{}, [], []})
    {deep, opts} = Keyword.pop(opts, :deep, false)

    into =
      quote location: :keep do
        Enum.into(unquote(into), %{}, fn {k, v} -> {to_string(k), v} end)
      end

    quote do
      use GenServer
      use Camarero.Tapas, into: unquote(into)

      @behaviour Camarero.Plato

      @impl Camarero.Plato
      def plato_all, do: GenServer.call(__MODULE__, :plato_all)

      @impl Camarero.Plato
      def plato_get(key) when is_atom(key),
        do: key |> to_string() |> plato_get()

      @impl Camarero.Plato
      def plato_get(key) when is_binary(key),
        do: GenServer.call(__MODULE__, {:plato_get, key})

      @impl Camarero.Plato
      def plato_put(key, value) when is_atom(key),
        do: key |> to_string() |> plato_put(value)

      @impl Camarero.Plato
      def plato_put(key, value) when is_binary(key),
        do: GenServer.cast(__MODULE__, {:plato_put, {key, value}})

      @impl Camarero.Plato
      def plato_delete(key) when is_atom(key),
        do: key |> to_string() |> plato_delete()

      @impl Camarero.Plato
      def plato_delete(key) when is_binary(key),
        do: GenServer.call(__MODULE__, {:plato_delete, key})

      @impl Camarero.Plato
      case unquote(deep) do
        false ->
          def plato_route do
            __MODULE__
            |> Macro.underscore()
            |> String.split("/")
            |> Enum.reverse()
            |> hd()
          end

        true ->
          def plato_route do
            __MODULE__
            |> Macro.underscore()
            |> String.trim_leading("/")
            |> String.trim_leading("camarero/carta")
            |> String.trim_leading("/")
          end

        path when is_binary(path) ->
          def plato_route do
            path = String.trim(path, "/")

            __MODULE__
            |> Macro.underscore()
            |> String.trim_leading("/")
            |> String.trim_leading("path")
            |> String.trim_leading("/")
          end
      end

      @impl Camarero.Plato
      def reshape(%{"key" => _, "value" => _} = map), do: map
      def reshape(%{"id" => id} = map), do: %{"key" => id, "value" => map}
      def reshape(%{"uuid" => id} = map), do: %{"key" => id, "value" => map}
      def reshape(map), do: map

      @impl Camarero.Plato
      def reshape(params, _extra), do: reshape(params)

      defoverridable reshape: 1, reshape: 2

      @doc ~s"""
      Starts the `#{__MODULE__}` linked to the current process.
      """
      @spec start_link(into :: Enum.t(), opts :: Keyword.t()) ::
              {:ok, pid()} | {:error, {:already_started, pid()} | term()}
      def start_link(into \\ [], opts \\ unquote(opts))

      def start_link([], opts), do: start_link(tapas_into(), opts)

      def start_link(into, opts) do
        GenServer.start_link(
          __MODULE__,
          into,
          Keyword.put_new(opts, :name, __MODULE__)
        )
      end

      @impl GenServer
      def init(into), do: {:ok, into}

      @impl GenServer
      def handle_call(:plato_all, _from, state),
        do: {:reply, state, state}

      @impl GenServer
      def handle_call({:plato_get, key}, _from, state) do
        {:reply, tapas_get(state, key), state}
      end

      @impl GenServer
      def handle_cast({:plato_put, {key, value}}, state) do
        {_, result} = tapas_put(state, key, value)
        {:noreply, result}
      end

      @impl GenServer
      def handle_call({:plato_delete, key}, _from, state) do
        {value, result} = tapas_delete(state, key)
        {:reply, value, result}
      end

      defoverridable Camarero.Plato
    end
  end
end
