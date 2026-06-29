defmodule CLIX.SpecNG.Normalization do
  @moduledoc false

  @doc false
  def normalize({cmd_name, cmd_pair}) do
    {cmd_name, cmd_pair}
  end

  # defp fill_cmd_pair({cmd_name, cmd_spec}) do
  #   cmd_spec =
  #     cmd_spec
  #     |> Map.update!(:args, fn args -> Enum.map(args, &fill_arg_pair(&1)) end)
  #     |> Map.update!(:opts, fn opts -> Enum.map(opts, &fill_opt_pair(&1)) end)
  #     |> Map.update!(:cmds, fn cmds -> Enum.map(cmds, &fill_cmd_pair(&1)) end)

  #   {cmd_name, cmd_spec}
  # end

  # defp fill_arg_pair({arg_name, arg_spec}) do
  #   arg_spec = arg_spec |> put_arg_value_name(arg_name)
  #   {arg_name, arg_spec}
  # end

  # defp fill_opt_pair({opt_name, opt_spec}) do
  #   opt_spec = opt_spec |> put_opt_value_name(opt_name)
  #   {opt_name, opt_spec}
  # end

  # defp put_arg_value_name(%{value_name: nil} = arg_spec, arg_name) do
  #   value_name = arg_name |> to_string() |> String.upcase()
  #   Map.put(arg_spec, :value_name, value_name)
  # end

  # defp put_arg_value_name(arg_spec, _arg_name), do: arg_spec

  # defp put_opt_value_name(%{value_name: nil} = opt_spec, opt_name) do
  #   value_name = opt_name |> to_string() |> String.upcase()
  #   Map.put(opt_spec, :value_name, value_name)
  # end

  # defp put_opt_value_name(opt_spec, _opt_name), do: opt_spec

  ##

  # defp normalize_num_args(n) when is_integer(n), do: {n, n}
  # defp normalize_num_args({min, max}), do: {min, max}
end
