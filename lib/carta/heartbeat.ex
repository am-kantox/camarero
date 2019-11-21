defmodule Camarero.Carta.Heartbeat do
  @moduledoc """
  Ready-to-go implementation of the hearbeat; responds with 200 / empty object
    at `"/api/v1/heartbeat"` endpoint.
  """

  # , as: Camarero
  use Camarero
end
