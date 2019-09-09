defmodule Camarero.Carta.PlainResponse do
  @moduledoc false
  use Camarero, as: Camarero, response_as: :value
end

defmodule Camarero.Carta.Crud do
  @moduledoc false
  use Camarero, as: Camarero, methods: ~w|post put get delete|a
end
