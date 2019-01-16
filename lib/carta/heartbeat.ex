defmodule Camarero.Carta.Heartbeat do
  @moduledoc """
  Ready-to-go implementation of the hearbeat; responds with 200 / empty object
    at `"/api/v1/heartbeat"` endpoint.
  """

  use Camarero, as: Camarero, methods: ~w|post get delete|a
end
