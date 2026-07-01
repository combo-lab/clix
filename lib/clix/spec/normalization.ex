defmodule CLIX.SpecNG.Normalization do
  @moduledoc false

  # sugar→canonical, flag cleanup, required adjustment
  # action 推导、default 注入、num_values 归一化
  # normalize 层：sugar → canonical、action 推断、default 注入
  # 转化 cmd_spec, arg_spec, opt_spec 为对应的结构体 Cmd, Arg, Opt
  #
  # TODO: arg :required 默认值推导
  #   arg 默认 required: true,但当 num_values unwrap 到 min == 0 (如 {0, 1}) 且
  #   用户未显式设 :required 时,应默认 required: false (与 argparse nargs='?' 一致)。
  #   semantics 已挡住显式 required:true 与 min=0 num_values 的矛盾组合。
  # TODO: opt :required 默认值推导
  #   opt 默认 required: false,但 flag action 不应与 required:true 组合
  #   (semantics 已挡),其余情况按用户显式 :required 或默认 false。

  # 只写 default_value 没写 required，改写 required: false。

  # 对于 flag_action，改写
  # + value_name: nil
  # + num_values: {0, 0}
  # + value_parser: nil,
  # + required: false
  # + default_value: nil

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

  # defp normalize_num_values(n) when is_integer(n), do: {n, n}
  # defp normalize_num_values({min, max}), do: {min, max}
end
