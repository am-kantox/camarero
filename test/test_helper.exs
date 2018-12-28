defmodule Camarero.Carta.DynamicHeartbeat do
  use Camarero.Plato

  @impl true
  def plato_get(key) when is_atom(key), do: super(key)
  def plato_get(key) when is_binary(key), do: super(key)
end

ExUnit.start()
