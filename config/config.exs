import Config

config :camarero,
  carta: [],
  # catering: [
  #   max_restarts: 3,
  #   max_seconds: 5,
  #   max_children: :infinity,
  #   extra_arguments: []
  # ],
  root: "api/v1",
  cowboy: [scheme: :http, options: [port: 4001]]

config :logger, :console,
  format: "\n$message\n$date $time [$level] $metadata\n",
  level: :debug,
  metadata: [:file, :line, :handler, :endpoint, :cowboy]

if File.exists?("config/#{Mix.env()}.exs"), do: import_config("#{Mix.env()}.exs")
