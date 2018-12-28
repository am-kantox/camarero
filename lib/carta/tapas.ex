defmodule Camarero.Tapas do
  @moduledoc """
  This behaviour is high-level abstraction of the container begind handlers.

  Aññ handlers are supposed to implement this behaviour. The simplest way
  is to `use Camarero.Plato` in the handler module; that will inject
  the default boilerlate using `%{binary() => any()}` map as a container behind.

  Default implementation uses `Camarero.Tapas` as low-level container implementation.
  """

  @typedoc "`Camarero.Tapas` allows anything implementing `Access` behaviour as a container"
  @type t() :: Access.t()

  @doc """
  Returns the empty container to be used to store the data.

  The returned term must implement `Access` behaviour since it’d be used from CR[U]D
    operations (`c:tapas_get/2`, `c:tapas_put/3`, and `c:tapas_delete/2`).
  """
  @callback tapas_into() :: t()
  @doc "Retrieves from the container and returns the value for the key specified"
  @callback tapas_get(bag :: t(), key :: binary() | atom()) :: {:ok, any()} | :error
  @doc "Deletes the key-value pair for the key specified from the container"
  @callback tapas_delete(bag :: t(), key :: binary() | atom()) :: {any(), t()}
  @doc "Sets the value for the key specified (intended to be used from the application)"
  @callback tapas_put(bag :: t(), key :: binary() | atom(), value :: any()) :: {any(), t()}

  @doc false
  defmacro __using__(opts \\ []) do
    into = Keyword.get(opts, :into, %{})

    quote do
      @behaviour Camarero.Tapas

      @impl true
      def tapas_into(), do: unquote(Macro.escape(into))

      @impl true
      def tapas_get(bag, key) when is_atom(key), do: tapas_get(bag, to_string(key))

      @impl true
      def tapas_get(bag, key) when is_binary(key), do: Access.fetch(bag, key)

      @impl true
      def tapas_put(bag, key, value) when is_atom(key),
        do: tapas_put(bag, to_string(key), value)

      @impl true
      def tapas_put(bag, key, value) when is_binary(key),
        do: Access.get_and_update(bag, key, &{&1, value})

      @impl true
      def tapas_delete(bag, key) when is_atom(key),
        do: tapas_delete(bag, to_string(key))

      @impl true
      def tapas_delete(bag, key) when is_binary(key),
        do: Access.get_and_update(bag, key, fn _ -> :pop end)

      defoverridable Camarero.Tapas
    end
  end
end
