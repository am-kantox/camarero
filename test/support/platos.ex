defmodule Camarero.Carta.PlainResponse do
  use Camarero, as: Camarero, response_as: :value
end

defmodule Camarero.Carta.Crud do
  use Camarero, as: Camarero, methods: ~w|post get delete|a
end
