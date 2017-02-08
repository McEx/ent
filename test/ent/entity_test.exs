defmodule Ent.EntityTest.TickEvent do
  defstruct count: 0
end

defmodule Ent.EntityTest.TestRoute do
  use Ent.Route

  def dispatch(type, msg, _opts) do
    entity_module = Process.get(:ent_top_module)
    apply(entity_module, :ent_dispatch_event, [type, msg])
    :ok
  end

end

defmodule Ent.EntityTest.PositionComponent do
  use Ent.Component

  export_fun :set_position
  export_fun :get_position

  def init(_arg) do
    {:ok, {0, 0, 0}}
  end

  def set_position(position, _state) do
    {:ok, position}
  end

  def get_position(_, position) do
    {position, position}
  end

end

defmodule Ent.EntityTest.MovementComponent do
  use Ent.Component

  handle_event Ent.EntityTest.TickEvent, :on_tick
  handle_event :ent_init, :init_event

  use_local_fun Ent.EntityTest.PositionComponent, :get_position
  use_local_fun Ent.EntityTest.PositionComponent, :set_position

  def init(_args) do
    {:ok, nil}
  end

  def init_event(nil, nil) do
    nil
  end

  def on_tick(_event, nil) do
    {x, y, z} = get_position(nil)
    :ok = set_position {x + 1, y, z}
    nil
  end

end

defmodule Ent.EntityTest.Entity do
  use Ent.Entity

  component Ent.EntityTest.PositionComponent
  component Ent.EntityTest.MovementComponent

  def init_entity(_args) do
    {:ok, %{}}
  end

end

defmodule Ent.EntityTest do
  use ExUnit.Case

  test "basic entity interaction" do
    {:ok, entity} = Ent.EntityTest.Entity.start_link(%{})

    call = {:ent_call, {Ent.EntityTest.PositionComponent, :get_position}, nil}
    assert GenServer.call(entity, call) == {0, 0, 0}

    send entity, {:ent_event, Ent.EntityTest.TickEvent, nil}

    call = {:ent_call, {Ent.EntityTest.PositionComponent, :get_position}, nil}
    assert GenServer.call(entity, call) == {1, 0, 0}

  end

end
