if Code.ensure_loaded?(Envio) do
  defmodule Camarero.Spitter do
    @moduledoc false
    use Envio.Publisher, channel: :all

    def spit(what), do: broadcast(what)
    def spit(channel, what), do: broadcast(channel, what)
  end
else
  defmodule Camarero.Spitter do
    @moduledoc false
    require Logger

    def spit(what), do: Logger.info("[📦] " <> inspect(what))
    def spit(channel, what), do: Logger.info("[📦] @#{channel} " <> inspect(what))
  end
end
