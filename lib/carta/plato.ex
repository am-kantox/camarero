defmodule Camarero.Plato do
  @moduledoc """
  This behaviour is high-level abstraction of the container begind handlers.

  Aññ handlers are supposed to implement this behaviour. The simplest way
  is to `use Camarero.Plato` in the handler module; that will inject
  the default boilerlate using `%{binary() => any()}` map as a container behind.

  Default implementation uses `Camarero.Tapas` as low-level container implementation.
  """

  @doc "Returns the container itself, as is"
  @callback plato_all() :: Camarero.Tapas.t()
  @doc "Returns the value for the key specified"
  @callback plato_get(key :: binary() | atom()) ::
              {:ok, any()} | :error | {:error, {400 | 404 | non_neg_integer(), map()}}
  @doc "Sets the value for the key specified (intended to be used from the application)"
  @callback plato_put(key :: binary() | atom(), value :: any()) :: :ok
  @doc "Deletes the key-value pair for the key specified"
  @callback plato_delete(key :: binary() | atom()) :: {:ok, any()}
  @doc "Returns the route this module is supposed to be mounted to"
  @callback plato_route() :: binary()

  @doc false
  defmacro __using__(opts \\ []) do
    {into, opts} = Keyword.pop(opts, :into, {:%{}, [], []})

    into =
      quote location: :keep do
        Enum.into(unquote(into), %{}, fn {k, v} -> {to_string(k), v} end)
      end

    quote do
      use GenServer
      use Camarero.Tapas, into: unquote(into)

      @behaviour Camarero.Plato

      @impl true
      def plato_all, do: GenServer.call(__MODULE__, :plato_all)

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
      def plato_delete(key) when is_atom(key),
        do: key |> to_string() |> plato_delete()

      @impl true
      def plato_delete(key) when is_binary(key),
        do: GenServer.call(__MODULE__, {:plato_delete, key})

      @impl true
      def plato_route do
        __MODULE__
        |> Macro.underscore()
        |> String.split("/")
        |> Enum.reverse()
        |> hd()
      end

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

      @impl true
      def init(into), do: {:ok, into}

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

      @impl true
      def handle_call({:plato_delete, key}, _from, state) do
        {value, result} = tapas_delete(state, key)
        {:reply, value, result}
      end

      defoverridable Camarero.Plato
    end
  end
end
