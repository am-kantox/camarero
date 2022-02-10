# Camarero

## [![Kantox ❤ OSS](https://img.shields.io/badge/❤-kantox_oss-informational.svg)](https://kantox.com/)  ![Test](https://github.com/am-kantox/camarero/workflows/Test/badge.svg)  ![Dialyzer](https://github.com/am-kantox/camarero/workflows/Dialyzer/badge.svg) Lightweight Json API server, embeddable into any project

**Camarero** is a ready-to-use solution to add some JSON API functionality to your existing application, or to implement the read-only JSON API from the scratch when more sophisticated (read: heavy) solutions are not desirable.

![Camarero Ties](https://raw.githubusercontent.com/am-kantox/camarero/master/stuff/camarero.png)

It is designed to be very simple and handy for read-only web access to the data. It might be a good candidate to replace _Redis_ or any other key-value store. **It is blazingly, deadly fast**.

Here are response times for the 1M key-value storage behind.

![1M key-value storage lookup: 10μs±](https://raw.githubusercontent.com/am-kantox/camarero/master/stuff/1M.png)

## Implementation details

**Camarero** is supposed to be plugged into the functional application. It handles the configured routes/endpoints by delegating to the configured handler modules. The simplest configuration might looks like:

```elixir
config :camarero,
  carta: [Camarero.Carta.Heartbeat],
  root: "api/v1"
```

The above is the default; `/api/v1` would be the root of the web server, single `Camarero.Carta.Heartbeat` module is declared as handler. The handlers might be also added dynamically by calls to `Camarero.Catering.route!`.

### Handlers

_Handler_ is a module implementing `Camarero.Plato` behaviour. It consists of methods to manipulate the conteiner behind it. Any module might implement this behaviour to be used as a handler for incoming HTTP requests.

There is also `Camarero.Tapas` behaviour scaffolding the container implementation inside `Camarero.Plato`.

The default implementation using `%{}` map as a container, looks pretty simple:

```elixir
defmodule Camarero.Carta.Heartbeat do
  use Camarero
end
```

Three different scaffolding implementations are currently supported with `scaffold: :impl` keyword parameter passed to `use Camarero`:

- `scaffold: :full` [_default_] — the full implementation of `Camarero.Plato` is used;
- `scaffold: :access` — `Camarero.Tapas` implementation is scaffolded only;
- `scaffold: :none` — no scaffold is used.

This is an exact exerpt from `Heartbeat` module that comes with this package. For more complicated/sophisticated usages please refer to the [documentation](https://hexdocs.pm/camarero).

All the methods from both `Camarero.Tapas` and `Camarero.Plato` default implementations are overridable. E. g. to use the custom route for the module (default is the not fully qualified underscored module name,) as well as custom container, one might do the following:

```elixir
defmodule Camarero.Carta.Heartbeat do
  use Camarero, into: %MyStructWithAccessBehaviour{}

  @impl Camarero.Plato
  def plato_route(), do: "internal/heartbeat"
end
```

### Web server config

**Camarero** runs over _Cowboy2_ with _Plug_. To configure _Cowboy_, one might specify in the `config.exs` file:

```elixir
config :camarero,
  cowboy: [port: 4001, scheme: :http, options: []]
```

## Installation

```elixir
def deps do
  [
    {:camarero, "~> 0.4"}
  ]
end
```

## Changelog

### `0.13`

- `Plato.reshape/1` to allow reshaping of any incoming data into expected `%{"key" => _, "value" => _}`
- make sure to use `v0.13.3` with latest `Plug` library

### `0.7`

- Added support for `HTTP PUT` method

### `0.5`

- Ability to subscribe to incoming requests with `Envío.Subscriber` (see `test/envio_test.exs` for inspiration.)

### `0.4`

- basic CRUD (`GET /`, `GET /:id`, `POST /`, `DELETE /:id`),
- better support for many handlers,
- `response_as: :value` to return raw values instead of valid JSON objects.

## Is it of any good?

Sure it is.

## Benchmarks

To benchmark the application one should install [`wrk`](https://github.com/wg/wrk),
run the application and _then_ run the `wrk.sh` script located in `wrk` folder.

Here are the results it produced on my laptop.

```
=================================================================
 NB! Make sure you have a running Camarero app:

      mix clean && mix run --preload-modules --no-halt
=================================================================

 Performing 10 sec POSTs and 5 sec GETs afterwards.
 This will INSERT 300K key-values approx and READ 200K approx.

=================================================================

Running 10s test @ http://127.0.0.1:4001/api/v1/crud
  24 threads and 1000 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    44.91ms   48.53ms 422.59ms   83.52%
    Req/Sec     1.29k   212.59     3.09k    74.36%
  311912 requests in 10.10s, 42.59MB read
Requests/sec:  30884.14
Transfer/sec:      4.22MB
Running 5s test @ http://127.0.0.1:4001/api/v1/crud
  24 threads and 1000 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    39.35ms   45.92ms 401.63ms   84.53%
    Req/Sec     1.48k   375.94     4.71k    79.09%
  179565 requests in 5.10s, 30.11MB read
Requests/sec:  35211.34
Transfer/sec:      5.90MB

=================================================================

 Performing 10 sec POSTs and 5 sec DELETEs afterwards.
 This will INSERT 300K key-values approx and DELETE 200K approx.

=================================================================

Running 10s test @ http://127.0.0.1:4001/api/v1/crud
  24 threads and 1000 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    46.32ms   52.38ms 457.89ms   84.01%
    Req/Sec     1.31k   302.33     5.09k    79.26%
  316401 requests in 10.10s, 43.20MB read
Requests/sec:  31332.56
Transfer/sec:      4.28MB
Running 5s test @ http://127.0.0.1:4001/api/v1/crud
  24 threads and 1000 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    40.17ms   46.46ms 406.37ms   84.13%
    Req/Sec     1.49k   360.10     6.55k    84.83%
  179722 requests in 5.10s, 38.97MB read
Requests/sec:  35241.01
Transfer/sec:      7.64MB

=================================================================
```

## [Documentation](http://hexdocs.pm/camarero)
