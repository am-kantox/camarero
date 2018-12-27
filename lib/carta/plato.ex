defmodule Camarero.Plato do
  @callback get(key :: binary()) :: map()
  @callback put(key :: binary(), value :: map()) :: :ok

  defmacro __using__(bag \\ []) do
    quote do
      use GenServer
      @behaviour Camarero.Plato
      @initial unquote(Macro.escape(Enum.into(bag, %{})))

      def get(key) when is_binary(key),
        do: GenServer.call(__MODULE__, {:get, key})

      def put(key, %{} = value) when is_binary(key),
        do: GenServer.cast(__MODULE__, {:put, {key, value}})

      def start_link(initial \\ [], opts \\ [])

      def start_link([], opts), do: start_link(@initial, opts)

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
      def handle_call({:get, key}, _from, state),
        do: {:reply, Map.get(state, key), state}

      @impl true
      def handle_cast({:put, {key, value}}, state),
        do: {:noreply, Map.put(state, key, value)}
    end
  end
end
