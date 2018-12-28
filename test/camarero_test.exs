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

  test "allows dynamic routes" do
    Camarero.Catering.route!(Camarero.Carta.DynamicHeartbeat)
    Camarero.Carta.DynamicHeartbeat.plato_put("existing", 42)

    conn = conn(:get, "/api/v1/dynamic_heartbeat/existing")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, @opts)

    # Assert the route added
    assert Camarero.Catering.Routes.state() == %{
             "dynamic_heartbeat" => Camarero.Carta.DynamicHeartbeat,
             "heartbeat" => Camarero.Carta.Heartbeat
           }

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

  test "overriding of existing route is disallowed" do
    Camarero.Catering.route!(Camarero.Carta.DuplicateHeartbeat)
    assert Camarero.Catering.Routes.state()["heartbeat"] == Camarero.Carta.Heartbeat

    refute Enum.find(
             Map.values(Camarero.Catering.Routes.state()),
             &(&1 == Camarero.Carta.DuplicateHeartbeat)
           )
  end
end
