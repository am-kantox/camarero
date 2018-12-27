defmodule Camarero.Catering do
  @moduledoc false
  use DynamicSupervisor
  require Logger

  def start_link(extra_arguments \\ []) do
    with {:ok, pid} <- DynamicSupervisor.start_link(__MODULE__, extra_arguments, name: __MODULE__) do
      :camarero
      |> Application.get_env(:carta, [])
      |> Enum.each(&DynamicSupervisor.start_child(__MODULE__, &1))

      {:ok, pid}
    end
  end

  @impl true
  def init(extra_arguments) when is_list(extra_arguments) do
    with {max_restarts, extra_arguments} <- Keyword.pop(extra_arguments, :max_restarts, 3),
         {max_seconds, extra_arguments} <- Keyword.pop(extra_arguments, :max_seconds, 5),
         {max_children, extra_arguments} <- Keyword.pop(extra_arguments, :max_children, :infinity) do
      DynamicSupervisor.init(
        strategy: :one_for_one,
        max_restarts: max_restarts,
        max_seconds: max_seconds,
        max_children: max_children,
        extra_arguments: extra_arguments
      )
    end
  end
end
