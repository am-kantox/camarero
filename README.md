# Camarero

## [![CircleCI](https://circleci.com/gh/am-kantox/camarero.svg?style=svg)](https://circleci.com/gh/am-kantox/camarero) Lightweight Json API server, embeddable into any project

**Camarero** is a ready-to-use solution to add some JSON API functionality to your existing application, or to implement the read-only JSON API from the scratch when more sophisticated (read: heavy) solutions are not desirable.

![Camarero Ties](https://github.com/am/kantox/camarero/stuff/camarero.png?raw=true)

It is designed to be very simple and handy for read-only web access to the data. It might be a good candidate to replace _Redis_ or any other key-value store. **It is blazingly, dead fast.

Here are response times for the 1M key-value storage behind.

![1M key-value storage lookup: 10μs±](https://github.com/am/kantox/camarero/stuff/1M.png?raw=true)

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
  use Camarero.Plato
end
```

This is an exact exerpt from `Heartbeat` module that comes with this package. For more complicated/sophisticated usages please refer to the [documentation](https://hexdocs.pm/camarero).

All the methods from both `Camarero.Tapas` and `Camarero.Plato` default implementations are overridable. E. g. to use the custom route for the module (default is the not fully qualified underscored module name,) as well as custom container, one might do the following:

```elixir
defmodule Camarero.Carta.Heartbeat do
  use Camarero.Plato, container: %MyStructWithAccessBehaviour{}

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
    {:camarero, "~> 0.1"}
  ]
end
```

## Is it of any good?

Sure it is.
