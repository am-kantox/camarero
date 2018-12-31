defmodule Camarero.Property.Test do
  use ExUnit.Case, async: true
  use Plug.Test
  use ExUnitProperties

  import StreamData

  @opts Camarero.Handler.init([])

  defmacrop aib, do: quote(do: one_of([atom(:alphanumeric), integer()]))
  defmacrop key, do: quote(do: atom(:alphanumeric))

  defmacrop leaf_list, do: quote(do: list_of(aib()))
  defmacrop leaf_map, do: quote(do: map_of(key(), aib()))
  defmacrop leaf_keyword, do: quote(do: keyword_of(aib()))

  defmacrop leaf,
    do: quote(do: one_of([leaf_list(), leaf_map(), leaf_keyword()]))

  defmacrop key_value, do: quote(do: map_of(key(), leaf()))

  test "responds with 200 on existing key" do
    check all term <- key_value(), max_runs: 25 do
      Enum.each(term, fn {k, v} ->
        # do not check empties
        k = "foo_#{Atom.to_string(k)}"
        v = Iteraptor.jsonify(v, values: true)

        Camarero.Carta.Heartbeat.plato_put(k, v)
        conn = conn(:get, "/api/v1/heartbeat/#{k}")

        # Invoke the plug
        conn = Camarero.Handler.call(conn, @opts)

        # Assert the response and status
        assert conn.state == :sent
        assert conn.status == 200
        assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|key value|

        assert conn.resp_body |> Jason.decode!() |> Map.get("value") == v
      end)
    end
  end
end
