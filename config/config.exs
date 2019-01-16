use Mix.Config

if File.exists?("#{Mix.env()}.exs"), do: import_config("#{Mix.env()}.exs")
