use Mix.Config

config :camarero,
  carta: [Camarero.Carta.Crud, Camarero.Carta.Heartbeat, Camarero.Carta.PlainResponse],
  root: "api/v1",
  cowboy: [port: 4001, scheme: :http, options: []]
