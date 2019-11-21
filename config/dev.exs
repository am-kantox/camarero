import Config

config :camarero,
  carta: [Camarero.Carta.Heartbeat],
  root: "api/v1",
  cowboy: [port: 4001, scheme: :http, options: []]
