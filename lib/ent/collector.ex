defmodule Ent.Collector do

  @name __MODULE__

  @initial_state %{
    components: %{},
  }

  def begin do
    Agent.start_link(fn -> @initial_state end, name: @name)
  end

  def finish do
    state = Agent.get(@name, fn state -> state end)
    :ok = Agent.stop(@name)
    state
  end

  def add_component(env, dependencies) do
    IO.inspect env.module
    Agent.cast(@name, fn state ->
      put_in(state, [:components, env.module],
        %{dependencies: dependencies})
    end)
  end

end
