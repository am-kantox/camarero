defmodule Camarero.Carta.PlainResponse do
  @moduledoc false
  use Camarero, as: Camarero, response_as: :value
end

defmodule Camarero.Carta.Crud do
  @moduledoc false
  use Camarero, as: Camarero, methods: ~w|post put get delete|a
end

defmodule Camarero.Carta.Deeply.Nested.Crap do
  @moduledoc false
  use Camarero, as: Camarero, methods: ~w|post put get delete|a

  @impl Camarero.Plato
  def plato_route, do: "/deeply/nested/crap"
end

defmodule Camarero.Carta.Deeply.Nested.Deep do
  @moduledoc false
  use Camarero, as: Camarero, methods: ~w|post put get delete|a, deep: true
end
