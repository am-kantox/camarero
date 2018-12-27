defmodule Camarero.Catering do
  defmodule Routes do
    @moduledoc false
    @behaviour Access

    @type t() :: map()

    use Agent

    def start_link(_opts \\ [], _initial \\ %{}),
      do: Agent.start_link(fn -> %{} end, name: __MODULE__)

    def state(), do: Agent.get(__MODULE__, & &1)

    def get(key) when is_binary(key),
      do: __MODULE__ |> Agent.get(& &1) |> Map.get(key!(key))

    def put(key, value) when is_binary(key) and is_atom(value),
      do: Agent.update(__MODULE__, &Map.put(&1, key!(key), value))

    @impl true
    def fetch(__MODULE__, key) do
      __MODULE__
      |> Agent.get(& &1)
      |> Map.fetch(key!(key))
    end

    @impl true
    def get_and_update(__MODULE__, key, function),
      do: Agent.get_and_update(__MODULE__, &Map.get_and_update(&1, key!(key), function))

    @impl true
    def pop(__MODULE__, key) do
      {get(key!(key)), Agent.update(__MODULE__, &Map.delete(&1, key!(key)))}
    end

    defp key!(key), do: String.trim(key, "/")
  end

  @moduledoc false
  use DynamicSupervisor
  require Logger

  def start_link(extra_arguments \\ []) do
    with {:ok, pid} <- DynamicSupervisor.start_link(__MODULE__, extra_arguments, name: __MODULE__) do
      DynamicSupervisor.start_child(__MODULE__, Camarero.Catering.Routes)

      :camarero
      |> Application.get_env(:carta, [])
      |> Enum.each(&route!/1)

      {:ok, pid}
    end
  end

  @spec route!(Supervisor.child_spec() | {module(), term()} | module()) :: State.t()
  def route!(child_spec) when is_atom(child_spec) do
    with {:ok, _} <- DynamicSupervisor.start_child(__MODULE__, child_spec),
         do: Camarero.Catering.Routes.put(apply(child_spec, :route, []), child_spec)
  end

  def route!({module, params} = child_spec) when is_atom(module) and is_list(params) do
    with {:ok, _} <- DynamicSupervisor.start_child(__MODULE__, child_spec),
         do: Camarero.Catering.Routes.put(apply(module, :route, []), module)
  end

  def route!(%{start: {module, _, _}} = child_spec) do
    with {:ok, _} <- DynamicSupervisor.start_child(__MODULE__, child_spec),
         do: Camarero.Catering.Routes.put(apply(module, :route, []), module)
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
