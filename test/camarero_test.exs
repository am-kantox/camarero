defmodule CamareroTest do
  use ExUnit.Case
  use Plug.Test

  doctest Camarero

  @opts Camarero.Handler.init([])

  test "responds with 400 on completely wrong path" do
    conn = conn(:get, "/foo")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, @opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 400
    assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|error path|
  end

  test "responds with 404 on missing key" do
    conn = conn(:get, "/api/v1/heartbeat/foo")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, @opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 404
    assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|error key|
  end

  test "responds with 200 on existing key" do
    Camarero.Carta.Heartbeat.plato_put("existing", 42)

    conn = conn(:get, "/api/v1/heartbeat/existing")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, @opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|key value|
    assert conn.resp_body |> Jason.decode!() |> Map.get("value") == 42
  end

  test "responds with 200 on the whole resource" do
    Camarero.Carta.Heartbeat.plato_put("foo1", 42)

    conn = conn(:get, "/api/v1/heartbeat")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, @opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|key value|
    assert conn.resp_body |> Jason.decode!() |> Map.get("value") |> Map.get("foo1") == 42
  end

  test "allow plain responses via config" do
    Camarero.Catering.route!(Camarero.Carta.PlainResponse)
    Camarero.Carta.PlainResponse.plato_put("plain", 42)

    conn = conn(:get, "/api/v1/plain_response/plain")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, @opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body |> Jason.decode!() == 42
  end

  test "allows dynamic routes" do
    Camarero.Catering.route!(Camarero.Carta.DynamicHeartbeat)
    Camarero.Carta.DynamicHeartbeat.plato_put("existing", 42)

    conn = conn(:get, "/api/v1/dynamic_heartbeat/existing")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, @opts)

    # Assert the route added
    assert Camarero.Catering.Routes.state()["dynamic_heartbeat"] ==
             Camarero.Carta.DynamicHeartbeat

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|key value|
    assert conn.resp_body |> Jason.decode!() |> Map.get("value") == 42
  end

  test "allows deletion" do
    Camarero.Carta.DynamicHeartbeat.plato_put("temporary", 42)
    Camarero.Carta.DynamicHeartbeat.plato_delete("temporary")

    conn = conn(:get, "/api/v1/heartbeat/temporary")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, @opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 404
    assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|error key|
  end

  test "supports URL-encoded keys" do
    Camarero.Carta.Heartbeat.plato_put("USD/EUR", 42)

    conn = conn(:get, "/api/v1/heartbeat/USD%2FEUR")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, @opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|key value|
  end

  test "supports all CRUD methods" do
    conn =
      :post
      |> conn("/api/v1/crud", %{key: "foo", value: 42})
      |> Camarero.Handler.call(@opts)

    assert conn.status == 200

    conns =
      Enum.map(~w|get delete get delete|a, fn method ->
        method
        |> conn("/api/v1/crud/foo")
        |> Camarero.Handler.call(@opts)
      end)

    # Assert the response and status
    assert Enum.all?(conns, &(&1.state == :sent))
    [delete_ko, get_ko | ok] = Enum.reverse(conns)
    assert delete_ko.status == 412
    assert get_ko.status == 404
    assert Enum.all?(ok, &(&1.status == 200))

    # assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|key value|
  end

  test "overriding of existing route is disallowed" do
    Camarero.Catering.route!(Camarero.Carta.DuplicateHeartbeat)
    assert Camarero.Catering.Routes.state()["heartbeat"] == Camarero.Carta.Heartbeat

    refute Enum.find(
             Map.values(Camarero.Catering.Routes.state()),
             &(&1 == Camarero.Carta.DuplicateHeartbeat)
           )
  end
end
