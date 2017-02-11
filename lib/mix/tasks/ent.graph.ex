defmodule Mix.Tasks.Ent.Graph do
  use Mix.Task

  def run([]) do
    modules_deps = get_deps()

    File.mkdir "ent"

    components_dot = Ent.DotGenerator.deps_dot_from_collected(modules_deps)
    :ok = File.write! "ent/components.dot", components_dot

    :ok
  end

  defp get_deps() do
    Ent.Collector.begin
    force_compile()
    Ent.Collector.finish
  end

  defp force_compile do
    Enum.map Mix.Tasks.Compile.Elixir.manifests, &make_old_if_exists/1
    Mix.Task.reenable "compile.elixir"
    Mix.Task.run "compile"
    Mix.Task.run "compile.elixir"
  end

  defp make_old_if_exists(path) do
    :file.change_time(path, {{2000, 1, 1}, {0, 0, 0}})
  end

end
