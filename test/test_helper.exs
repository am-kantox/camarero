defmodule Camarero.Carta.DynamicHeartbeat do
  use Camarero, as: Camarero

  @impl Camarero.Plato
  def plato_get(key) when is_atom(key), do: super(key)

  @impl Camarero.Plato
  def plato_get(key) when is_binary(key), do: super(key)
end

defmodule Camarero.Carta.DuplicateHeartbeat do
  use Camarero, as: Camarero

  @impl Camarero.Plato
  def plato_route, do: "heartbeat"
end

ExUnit.start()
