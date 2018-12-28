defmodule Camarero.Plato do
  @callback plato_all() :: Camarero.Tapas.t()
  @callback plato_get(key :: binary() | atom()) ::
              {:ok, any()} | :error | {:error, {400 | 404 | non_neg_integer(), map()}}
  @callback plato_put(key :: binary() | atom(), value :: any()) :: :ok
  @callback plato_route() :: binary()

  defmacro __using__(opts \\ []) do
    into =
      Keyword.get(
        opts,
        :container,
        opts
        |> Keyword.get(:initial, [])
        |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
      )

    quote do
      use GenServer
      use Camarero.Tapas, into: unquote(into)

      @behaviour Camarero.Plato

      @impl true
      def plato_all(), do: GenServer.call(__MODULE__, :plato_all)

      @impl true
      def plato_get(key) when is_atom(key),
        do: key |> to_string() |> plato_get()

      @impl true
      def plato_get(key) when is_binary(key),
        do: GenServer.call(__MODULE__, {:plato_get, key})

      @impl true
      def plato_put(key, value) when is_atom(key),
        do: key |> to_string() |> plato_put(value)

      @impl true
      def plato_put(key, value) when is_binary(key),
        do: GenServer.cast(__MODULE__, {:plato_put, {key, value}})

      @impl true
      def plato_route() do
        __MODULE__
        |> Macro.underscore()
        |> String.split("/")
        |> Enum.reverse()
        |> hd()
      end

      def start_link(initial \\ [], opts \\ unquote(opts))

      def start_link([], opts), do: start_link(tapas_into(), opts)

      def start_link(initial, opts) do
        GenServer.start_link(
          __MODULE__,
          initial,
          Keyword.put_new(opts, :name, __MODULE__)
        )
      end

      @impl true
      def init(initial), do: {:ok, initial}

      @impl true
      def handle_call(:plato_all, _from, state),
        do: {:reply, state, state}

      @impl true
      def handle_call({:plato_get, key}, _from, state) do
        {:reply, tapas_get(state, key), state}
      end

      @impl true
      def handle_cast({:plato_put, {key, value}}, state) do
        {_, result} = tapas_put(state, key, value)
        {:noreply, result}
      end

      defoverridable Camarero.Plato
    end
  end
end
