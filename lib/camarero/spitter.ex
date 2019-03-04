defmodule Camarero.Spitter do
  use Envio.Publisher, channel: :all

  def spit(what), do: broadcast(what)
  def spit(channel, what), do: broadcast(channel, what)
end
