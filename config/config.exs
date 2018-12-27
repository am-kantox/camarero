use Mix.Config

config :camarero,
  carta: [Camarero.Carta.Heartbeat],
  root: "api/v1"

#     import_config "#{Mix.env()}.exs"
