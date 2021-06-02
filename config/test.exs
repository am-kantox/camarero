import Config

config :camarero,
  heartbeat: true,
  carta: [Camarero.Carta.Heartbeat, Camarero.Carta.Crud],
  root: "api/v1",
  cowboy: [port: 4001, scheme: :http, options: []]
