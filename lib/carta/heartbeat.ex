defmodule Camarero.Carta.Heartbeat do
  @moduledoc """
  Ready-to-go implementation of the hearbeat; responds with 299 / empty object
    at `"/api/v1/heartbeat"` endpoint.
  """
  use Camarero, scaffold: :full
end
