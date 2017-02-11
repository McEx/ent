defmodule Ent.Component do

  # Contains all game logic and state.

  # Can explicitly depend on other modules, should
  # ONLY call components it requires. This will prevent
  # call loops.

  # Can listen for events, register callable
  # functions, castable functions.

  @type state :: term
  @callback init(term) :: {:ok, state}

  @event_handlers_attr :ent_event_handlers
  @exported_funs_attr :ent_exported_funs
  @component_dependencies_attr :ent_component_dependencies

  defmacro __using__(_opts) do
    env = __CALLER__
    Module.register_attribute(env.module, @event_handlers_attr, accumulate: true)
    Module.register_attribute(env.module, @exported_funs_attr, accumulate: true)
    Module.register_attribute(env.module, @component_dependencies_attr, accumulate: true)

    quote location: :keep do
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      def init(_args) do
        {:ok, nil}
      end

      def send_event(event_type, event_data, route, route_opts \\ nil) do
        apply(route, :dispatch, [event_type, event_data, route_opts])
      end

      defoverridable [init: 1]
    end
  end

  defmacro __before_compile__(env) do
    mod = env.module

    component_deps =
      Module.get_attribute(mod, @component_dependencies_attr)
      |> Enum.dedup

    Ent.Collector.add_component(env, component_deps)

    static_funs = quote location: :keep do
      def ent_event_handlers do
        unquote(Module.get_attribute(mod, @event_handlers_attr))
      end
      def ent_exported_funs do
        unquote(Module.get_attribute(mod, @exported_funs_attr))
        end
      def ent_component_dependencies, do: unquote(component_deps)
    end

    [static_funs]
  end

  defmacro handle_event(event_module, handler_name) do
    entry = {event_module, handler_name}
    Module.put_attribute(__CALLER__.module, @event_handlers_attr, entry)
    nil
  end

  defmacro export_fun(name) do
    Module.put_attribute(__CALLER__.module, @exported_funs_attr, name)
    quote location: :keep do
      def call_fun(dest, unquote(name), arg) do
        GenServer.call({:ent_call, {unquote(__CALLER__.module), unquote(name)}, arg})
      end
      def cast_fun(dest, unquote(name), arg) do
        GenServer.cast({:ent_cast, {unquote(__CALLER__.module), unquote(name)}, arg})
      end
    end
  end

  defp validate_use_fun!(component, fun_name, caller) do
    component_exported_funs = apply(component, :ent_exported_funs, [])

    unless fun_name in component_exported_funs do
      raise CompileError,
        file: caller.file,
        line: caller.line,
        description: "Ent: Component function use error: No exported function '#{fun_name}' in component '#{component}'"
    end
  end

  defmacro use_local_fun(component, fun_name, alias_name \\ nil) do
    alias_name = alias_name || fun_name
    {component_evald, _} = Module.eval_quoted(__CALLER__, component)

    validate_use_fun!(component_evald, fun_name, __CALLER__)

    Module.put_attribute(__CALLER__.module, @component_dependencies_attr, component_evald)

    quote location: :keep do
      require unquote(component)

      def unquote(alias_name)(arg \\ nil) do
        state = Process.get(unquote(component))
        {ret, state} = unquote(component).unquote(fun_name)(arg, state)
        Process.put(unquote(component), state)
        ret
      end
    end
  end

  defmacro use_remote_fun_call(component, fun_name, alias_name \\ nil) do
    alias_name = alias_name || fun_name

    quote location: :keep do
      def unquote(alias_name)(dest, arg) do
        GenServer.call(dest, {:ent_call, {unquote(component), unquote(fun_name)}, arg})
      end
    end
  end

  defmacro use_remote_fun_cast(component, fun_name, alias_name \\ nil) do
    alias_name = alias_name || fun_name

    quote location: :keep do
      def unquote(alias_name)(dest, arg) do
        GenServer.cast(dest, {:ent_cast, {unquote(component), unquote(fun_name)}, arg})
      end
    end
  end

end
