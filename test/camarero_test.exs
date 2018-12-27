defmodule CamareroTest do
  use ExUnit.Case
  doctest Camarero

  test "greets the world" do
    assert Camarero.hello() == :world
  end
end
