import Config

config :camarero,
  heartbeat: true,
  carta: [
    Camarero.Carta.Heartbeat,
    Camarero.Carta.Crud,
    Camarero.Carta.Deeply.Nested.Crap,
    Camarero.Carta.Deeply.Nested.Deep
  ],
  root: "api/v1",
  cowboy: [port: 4001, scheme: :http, options: []]
