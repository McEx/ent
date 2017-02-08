defmodule Ent.Util.Ast do

  def expand(ast, env) do
    Macro.prewalk(ast, fn
      {_, _, _} = node -> Macro.expand(node, env)
      node -> node
    end)
  end

end
