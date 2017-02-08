defmodule Ent.Route.Local do
  use Ent.Route

  # The only route provided by Ent itself.
  # It will dispatch the event to all local components
  # only.

  def dispatch(type, message, _args) do
    events = Process.get(:ent_queued_events, [])
    events = [{type, message} | events]
    Process.put(:ent_queued_events, events)
    :ok
  end

end
