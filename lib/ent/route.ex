defmodule Ent.Route do

  # A destination for a broadcast.

  # A route is specified when sending a boardcast
  # from a component. Logic in the specific route
  # module determines how the message is delivered
  # and what other entities it finds its way to.

  # Only one route should be provided by the
  # framework, Ent.Route.Local, which broadcasts
  # the message to other components in the entity.

  # Examples of routes used in a real application
  # would be:
  # * Broadcast to all entities in world
  # * Broadcast to all entities in vicinity
  # * Broadcast to non-entity processes

  @type message_type :: any
  @type message :: any
  @type options :: any

  @callback dispatch(message_type, message, options) :: :ok

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
    end
  end

  defmacro use_local_fun(component, fun_name, alias_name \\ nil) do
    alias_name = alias_name || fun_name

    quote location: :keep do
      def unquote(alias_name)(arg \\ nil) do
        state = Process.get(unquote(component))
        {ret, state} = unquote(component).unquote(fun_name)(arg, state)
        Process.put(unquote(component), state)
        ret
      end
    end
  end

end
