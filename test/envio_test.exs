defmodule CamareroEnvioTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  use Plug.Test

  setup_all do
    {:ok, pid} = EnvioSucker.start_link()

    on_exit(fn ->
      IO.inspect(Envio.Channels.state(), label: "\n\nChannels")
      EnvioSucker.terminate(:normal, Envio.Channels.state())
    end)

    %{pid: pid, opts: Camarero.Handler.init([])}
  end

  test "gets the processed messages", ctx do
    :get
    |> conn("/foo")
    |> Camarero.Handler.call(ctx.opts)

    Process.sleep(1_000)
  end
end
