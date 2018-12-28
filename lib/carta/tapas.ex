defmodule Camarero.Tapas do
  @type t() :: Access.t()

  @callback tapas_into() :: t()
  @callback tapas_get(bag :: t(), key :: binary() | atom()) :: {:ok, any()} | :error
  @callback tapas_delete(bag :: t(), key :: binary() | atom()) :: {any(), t()}
  @callback tapas_put(bag :: t(), key :: binary() | atom(), value :: any()) :: {any(), t()}

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
