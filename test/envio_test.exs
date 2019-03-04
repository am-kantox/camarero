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

    %{pid: pid}
  end

  @opts Camarero.Handler.init([])

  test "gets the processed messages" do
    :get
    |> conn("/foo")
    |> Camarero.Handler.call(@opts)

    Process.sleep(1_000)
  end
end
