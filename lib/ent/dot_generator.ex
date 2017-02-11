defmodule Ent.DotGenerator do

  def deps_dot_from_collected(%{components: components}) do
    [
      "digraph {\n",
      Enum.map(components, &dot_from_component_deps/1),
      "}\n",
    ]
  end

  defp dot_from_component_deps({module, props}) do
    deps_dot = props.dependencies |> Enum.map(&module_name/1) |> Enum.intersperse(" ")
    [
      module_name(module), ";\n",
      module_name(module), " -> { ", deps_dot, " };\n",
    ]
  end

  defp module_name(module) do
    ["\"", Atom.to_string(module), "\""]
  end

end
