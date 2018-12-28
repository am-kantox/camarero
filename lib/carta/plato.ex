defmodule Camarero.Plato do
  @callback all() :: Camarero.Tapas.t()
  @callback get(key :: binary() | atom()) ::
              {:ok, any()} | :error | {:error, {400 | 404 | non_neg_integer(), map()}}
  @callback put(key :: binary() | atom(), value :: any()) :: :ok
  @callback route() :: binary()

  defmacro __using__(opts \\ []) do
    quote do
      use GenServer

      use Camarero.Tapas,
        into: unquote(Enum.into(opts, %{}, fn {k, v} -> {to_string(k), v} end))

      @behaviour Camarero.Plato

      @impl true
      def all(), do: GenServer.call(__MODULE__, :all)

      @impl true
      def get(key) when is_atom(key),
        do: key |> to_string() |> get()

      @impl true
      def get(key) when is_binary(key),
        do: GenServer.call(__MODULE__, {:get, key})

      @impl true
      def put(key, value) when is_atom(key),
        do: key |> to_string() |> put(value)

      @impl true
      def put(key, value) when is_binary(key),
        do: GenServer.cast(__MODULE__, {:put, {key, value}})

      @impl true
      def route() do
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
      def handle_call(:all, _from, state),
        do: {:reply, state, state}

      @impl true
      def handle_call({:get, key}, _from, state) do
        {:reply, tapas_get(state, key), state}
      end

      @impl true
      def handle_cast({:put, {key, value}}, state) do
        {_, result} = tapas_put(state, key, value)
        {:noreply, result}
      end

      defoverridable Camarero.Plato
    end
  end
end
