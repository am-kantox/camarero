defmodule Camarero.Carta.Heartbeat do
  use Camarero.Plato

  @impl true
  def get(key) when is_atom(key), do: super(key)
  def get(key) when is_binary(key), do: super(key)
end
