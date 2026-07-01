defmodule CLIX.Spec.Helper do
  @moduledoc false

  def location(cmd_path, :cmd) when is_list(cmd_path) do
    "under the cmd path #{inspect(Enum.reverse(cmd_path))} - "
  end

  def location(cmd_path, {:arg, arg_name}) when is_list(cmd_path) do
    "arg #{inspect(arg_name)} under the cmd path #{inspect(Enum.reverse(cmd_path))} - "
  end

  def location(cmd_path, {:opt, opt_name}) when is_list(cmd_path) do
    "opt #{inspect(opt_name)} under the cmd path #{inspect(Enum.reverse(cmd_path))} - "
  end
end
