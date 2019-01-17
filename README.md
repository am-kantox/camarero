# Camarero

## [![CircleCI](https://circleci.com/gh/am-kantox/camarero.svg?style=svg)](https://circleci.com/gh/am-kantox/camarero) Lightweight Json API server, embeddable into any project

**Camarero** is a ready-to-use solution to add some JSON API functionality to your existing application, or to implement the read-only JSON API from the scratch when more sophisticated (read: heavy) solutions are not desirable.

![Camarero Ties](https://raw.githubusercontent.com/am-kantox/camarero/master/stuff/camarero.png)

It is designed to be very simple and handy for read-only web access to the data. It might be a good candidate to replace _Redis_ or any other key-value store. **It is blazingly, dead fast.

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

  @impl true
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

### `0.4.0`

- basic CRUD (`GET /`, `GET /:id`, `POST /`, `DELETE /:id`),
- better support for many handlers,
- `response_as: :value` to return raw values instead of valid JSON objects.

## Is it of any good?

Sure it is.

## [Documentation](http://hexdocs.pm/camarero)
