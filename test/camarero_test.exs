defmodule CamareroTest do
  use ExUnit.Case
  use Plug.Test

  doctest Camarero

  setup_all do
    %{opts: Camarero.Handler.init([])}
  end

  test "responds with 400 on completely wrong path", ctx do
    conn = conn(:get, "/foo")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, ctx.opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 400
    assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|error path|
  end

  test "responds with 404 on missing key", ctx do
    conn = conn(:get, "/api/v1/heartbeat/foo")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, ctx.opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 404
    assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|error key|
  end

  test "responds with 200 on existing key", ctx do
    Camarero.Carta.Heartbeat.plato_put("existing", 42)

    conn = conn(:get, "/api/v1/heartbeat/existing")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, ctx.opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|key value|
    assert conn.resp_body |> Jason.decode!() |> Map.get("value") == 42
  end

  test "responds with 200 on the whole resource", ctx do
    Camarero.Carta.Heartbeat.plato_put("foo1", 42)

    conn = conn(:get, "/api/v1/heartbeat")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, ctx.opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|key value|
    assert conn.resp_body |> Jason.decode!() |> Map.get("value") |> Map.get("foo1") == 42
  end

  # test "allow Keyword as plato", ctx do
  #   Camarero.Catering.route!(Camarero.Carta.IntoKw)
  #   Camarero.Carta.IntoKw.plato_put("plain", 42)

  #   conn = conn(:get, "/api/v1/into_kw/plain")

  #   # Invoke the plug
  #   conn = Camarero.Handler.call(conn, ctx.opts)

  #   # Assert the response and status
  #   assert conn.state == :sent
  #   assert conn.status == 200
  #   assert conn.resp_body |> Jason.decode!() == 42
  # end

  test "allow plain responses via config", ctx do
    Camarero.Catering.route!(Camarero.Carta.PlainResponse)
    Camarero.Carta.PlainResponse.plato_put("plain", 42)

    conn = conn(:get, "/api/v1/plain_response/plain")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, ctx.opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body |> Jason.decode!() == 42
  end

  test "allows dynamic routes", ctx do
    Camarero.Catering.route!(Camarero.Carta.DynamicHeartbeat)
    Camarero.Carta.DynamicHeartbeat.plato_put("existing", 42)

    conn = conn(:get, "/api/v1/dynamic_heartbeat/existing")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, ctx.opts)

    # Assert the route added
    assert Camarero.Catering.Routes.state()["dynamic_heartbeat"] ==
             Camarero.Carta.DynamicHeartbeat

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|key value|
    assert conn.resp_body |> Jason.decode!() |> Map.get("value") == 42
  end

  test "allows deletion", ctx do
    Camarero.Catering.route!(Camarero.Carta.DynamicHeartbeat)
    Camarero.Carta.DynamicHeartbeat.plato_put("temporary", 42)
    Camarero.Carta.DynamicHeartbeat.plato_delete("temporary")

    conn = conn(:get, "/api/v1/heartbeat/temporary")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, ctx.opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 404
    assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|error key|
  end

  test "supports URL-encoded keys", ctx do
    Camarero.Carta.Heartbeat.plato_put("USD/EUR", 42)

    conn = conn(:get, "/api/v1/heartbeat/USD%2FEUR")

    # Invoke the plug
    conn = Camarero.Handler.call(conn, ctx.opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body |> Jason.decode!() |> Map.keys() == ~w|key value|
  end

  test "supports all CRUD methods", ctx do
    conn =
      :post
      |> conn("/api/v1/crud", %{key: "foo", value: 42})
      |> Camarero.Handler.call(ctx.opts)

    assert conn.status == 201

    conns =
      Enum.map(~w|get delete get delete|a, fn method ->
        method
        |> conn("/api/v1/crud/foo")
        |> Camarero.Handler.call(ctx.opts)
      end)

    # Assert the response and status
    assert Enum.all?(conns, &(&1.state == :sent))
    [delete_ko, get_ko | ok] = Enum.reverse(conns)
    assert delete_ko.status == 404
    assert get_ko.status == 404
    assert Enum.all?(ok, &(&1.status == 200))

    conn =
      :put
      |> conn("/api/v1/crud/foo", %{value: 42})
      |> Camarero.Handler.call(ctx.opts)

    assert conn.status == 200

    conns =
      Enum.map(~w|get delete get delete|a, fn method ->
        method
        |> conn("/api/v1/crud/foo")
        |> Camarero.Handler.call(ctx.opts)
      end)

    # Assert the response and status
    assert Enum.all?(conns, &(&1.state == :sent))
    [delete_ko, get_ko | ok] = Enum.reverse(conns)
    assert delete_ko.status == 404
    assert get_ko.status == 404
    assert Enum.all?(ok, &(&1.status == 200))
  end

  test "supports all CRUD methods with reshape", ctx do
    conn =
      :post
      |> conn("/api/v1/crud", %{id: "foo", value: 42})
      |> Camarero.Handler.call(ctx.opts)

    assert conn.status == 201

    conns =
      Enum.map(~w|get delete get delete|a, fn method ->
        method
        |> conn("/api/v1/crud/foo")
        |> Camarero.Handler.call(ctx.opts)
      end)

    # Assert the response and status
    assert Enum.all?(conns, &(&1.state == :sent))
    [delete_ko, get_ko | ok] = Enum.reverse(conns)
    assert delete_ko.status == 404
    assert get_ko.status == 404
    assert Enum.all?(ok, &(&1.status == 200))
  end

  test "supports deeply nested routes via `plato_route/0`", ctx do
    conn =
      :post
      |> conn("/api/v1/deeply/nested/crap", %{key: "foo", value: 42})
      |> Camarero.Handler.call(ctx.opts)

    assert conn.status == 201

    conns =
      Enum.map(~w|get delete get delete|a, fn method ->
        method
        |> conn("/api/v1/deeply/nested/crap/foo")
        |> Camarero.Handler.call(ctx.opts)
      end)

    # Assert the response and status
    assert Enum.all?(conns, &(&1.state == :sent))
    [delete_ko, get_ko | ok] = Enum.reverse(conns)
    assert delete_ko.status == 404
    assert get_ko.status == 404
    assert Enum.all?(ok, &(&1.status == 200))

    conn =
      :put
      |> conn("/api/v1/deeply/nested/crap/foo", %{value: 42})
      |> Camarero.Handler.call(ctx.opts)

    assert conn.status == 200

    conns =
      Enum.map(~w|get delete get delete|a, fn method ->
        method
        |> conn("/api/v1/deeply/nested/crap/foo")
        |> Camarero.Handler.call(ctx.opts)
      end)

    # Assert the response and status
    assert Enum.all?(conns, &(&1.state == :sent))
    [delete_ko, get_ko | ok] = Enum.reverse(conns)
    assert delete_ko.status == 404
    assert get_ko.status == 404
    assert Enum.all?(ok, &(&1.status == 200))
  end

  test "supports deeply nested routes via `deep: true`", ctx do
    conn =
      :post
      |> conn("/api/v1/deeply/nested/deep", %{key: "foo", value: 42})
      |> Camarero.Handler.call(ctx.opts)

    assert conn.status == 201

    conns =
      Enum.map(~w|get delete get delete|a, fn method ->
        method
        |> conn("/api/v1/deeply/nested/deep/foo")
        |> Camarero.Handler.call(ctx.opts)
      end)

    # Assert the response and status
    assert Enum.all?(conns, &(&1.state == :sent))
    [delete_ko, get_ko | ok] = Enum.reverse(conns)
    assert delete_ko.status == 404
    assert get_ko.status == 404
    assert Enum.all?(ok, &(&1.status == 200))

    conn =
      :put
      |> conn("/api/v1/deeply/nested/deep/foo", %{value: 42})
      |> Camarero.Handler.call(ctx.opts)

    assert conn.status == 200

    conns =
      Enum.map(~w|get delete get delete|a, fn method ->
        method
        |> conn("/api/v1/deeply/nested/deep/foo")
        |> Camarero.Handler.call(ctx.opts)
      end)

    # Assert the response and status
    assert Enum.all?(conns, &(&1.state == :sent))
    [delete_ko, get_ko | ok] = Enum.reverse(conns)
    assert delete_ko.status == 404
    assert get_ko.status == 404
    assert Enum.all?(ok, &(&1.status == 200))
  end

  test "overriding of existing route is disallowed", _ctx do
    Camarero.Catering.route!(Camarero.Carta.DuplicateHeartbeat)
    assert Camarero.Catering.Routes.state()["heartbeat"] == Camarero.Carta.Heartbeat

    refute Enum.find(
             Map.values(Camarero.Catering.Routes.state()),
             &(&1 == Camarero.Carta.DuplicateHeartbeat)
           )
  end
end
