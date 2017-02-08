defmodule Ent.Entity do

  # DSL for specifying what components the entity is
  # composed of.

  # The generated module should implement a GenServer
  # interface.

  @type component :: module

  @callback init_entity(term) :: {:ok, %{component => term}}

  @components_attr :ent_components
  @module_prop :ent_top_module

  defmacro __using__(_opts) do
    env = __CALLER__

    # Attribute where components are stored as they are specified in the
    # module. This is read and used in after_compile.
    Module.register_attribute(env.module, @components_attr, accumulate: true)

    quote location: :keep do
      use GenServer
      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)

      def start(args) do
        GenServer.start(__MODULE__, args)
      end
      def start_link(args) do
        GenServer.start_link(__MODULE__, args)
      end

      def init(args) do
        Process.put(unquote(@module_prop), __MODULE__)

        {:ok, component_args} = init_entity(args)
        for component <- ent_components do
          component_arg = Map.get(component_args, component)
          {:ok, component_state} = apply(component, :init, [component_arg])
          Process.put(component, component_state)
        end

        ent_dispatch_event(:ent_init, nil)

        {:ok, nil}
      end

      defp ent_send_events do
        Process.get(:ent_queued_events, [])
        |> Enum.each(fn {type, data} ->
          ent_dispatch_event(type, data)
        end)
        #|> Enum.each(fn {type, data, route, route_opts} ->
        #  :ok = apply(route, :dispatch, [type, data, route_opts])
        #end)
        Process.put(:ent_queued_events, [])
        :ok
      end

      # Genserver clauses for external calls and messages.
      def handle_call({:ent_call, fun, arg}, _from, state) do
        ret = ent_do_call(fun, arg)
        {:reply, ret, state}
      end
      def handle_cast({:ent_cast, fun, arg}, state) do
        ent_do_call(fun, arg)
        {:noreply, state}
      end
      def handle_info({:ent_event, type, arg}, state) do
        ent_dispatch_event(type, arg)
        {:noreply, state}
      end

    end
  end

  # Collects and processes the event handlers from the list of
  # component modules.
  # Because of how event dispatcher functions are defined, this
  # also groups handlers by event type.
  defp process_event_handlers(components) do
    components
    |> Enum.map(&{&1, apply(&1, :ent_event_handlers, [])})
    |> Enum.map(fn {mod, handlers} ->
      Enum.map(handlers, fn {event_mod, handler} ->
        {mod, handler, event_mod}
      end)
    end)
    |> Enum.concat
    |> Enum.group_by(&elem(&1, 2))
  end

  defp process_exported_funs(components) do
    components
    |> Enum.map(&{&1, apply(&1, :ent_exported_funs, [])})
    |> Enum.map(fn {mod, calls} ->
      Enum.map(calls, &{mod, &1})
    end)
    |> Enum.concat
  end

  # This will make sure all components in 'modules' have their
  # component dependencies satisfied.
  defp validate_dependencies?(modules) do
    modules_deps =
      modules
      |> Enum.map(&{&1, apply(&1, :ent_component_dependencies, [])})

    Enum.reduce(modules_deps, [], fn({mod, deps}, acc) ->
      errs = Enum.reduce(deps, [], fn(dep, acc_i) ->
        if dep in modules do
          acc_i
        else
          [{mod, dep} | acc_i]
        end
      end)
      [errs | acc]
    end)
    |> Enum.concat
  end

  defp validate_dependencies!(modules, caller) do
    case validate_dependencies?(modules) do
      [] -> nil
      [{mod, dep} | _] ->
        raise CompileError,
          file: caller.file,
          line: caller.line,
          description: "Ent: Component dependency error: '#{mod}' depends on '#{dep}', but '#{caller.module}' does not have it."
    end
  end

  defmacro __before_compile__(env) do
    caller_mod = __CALLER__.module
    components = Module.get_attribute(__CALLER__.module, @components_attr)

    # Make sure we have a complete dependency tree.
    validate_dependencies!(components, __CALLER__)

    event_handlers = process_event_handlers(components)
    exported_funs = process_exported_funs(components)

    # Define event dispatcher functions.
    event_funs = for {event_type, handlers} <- event_handlers do
      event_dispatchers = Enum.map(handlers, fn {mod, fun_name, _} ->
        quote location: :keep do
          state = Process.get(unquote(mod))
          state = unquote(mod).unquote(fun_name)(msg, state)
          Process.put(unquote(mod), state)
        end
      end)

      quote location: :keep do
        def ent_dispatch_event(unquote(event_type), msg) do
          unquote(event_dispatchers)
          ent_send_events
          :ok
        end
      end
    end

    # Define call dispatcher functions.
    exported_funs_funs = for {mod, fun_name} <- exported_funs do
      quote location: :keep do
        def ent_do_call({unquote(mod), unquote(fun_name)}, arg) do
          state = Process.get(unquote(mod))
          {ret, state} = unquote(mod).unquote(fun_name)(arg, state)
          Process.put(unquote(mod), state)
          ent_send_events
          ret
        end
      end
    end

    static_funs = quote location: :keep do
      def ent_components, do: unquote(components)
      def ent_defined_functions, do: unquote(exported_funs)

      def ent_do_call(mod, fun_name, arg) do
        raise "Invalid call #{mod}.#{fun_name}(#{arg}) on entity #{unquote(caller_mod)}"
      end
      def ent_dispatch_event(event_type, msg) do
        raise "Invalid event type '#{event_type}' (#{}) on entity #{unquote(caller_mod)}"
      end
    end

    [event_funs, exported_funs_funs, static_funs]
  end

  @doc """
  Plugs a component into an entity module.

  This requires you to have used the 'Ent.Entity' module before use.

  A compile-time warning will be thrown if there are any dependency errors
  between your components.
  """
  defmacro component(module) do
    # This is normally bad practice, but because we use the value at
    # compile-time, we have little choice.
    {module_evald, _} = Module.eval_quoted(__CALLER__, module)

    Module.put_attribute(__CALLER__.module, @components_attr, module_evald)
    nil
  end

end
