defmodule CLIX.SpecNG.Types do
  @moduledoc false

  import CLIX.SpecNG, only: [location: 2, value_actions: 0, flag_actions: 0]

  @doc false
  def check!({cmd_name, cmd_spec}, cmd_path),
    do: check_cmd_pair!({cmd_name, cmd_spec}, cmd_path)

  defp check_cmd_pair!({cmd_name, cmd_spec}, cmd_path) do
    if not is_atom(cmd_name) do
      raise ArgumentError,
            location(cmd_path, :cmd) <>
              "expected cmd_name to be an atom, got: #{inspect(cmd_name)}"
    end

    if not is_map(cmd_spec) do
      raise ArgumentError,
            location(cmd_path, :cmd) <>
              "expected cmd_spec to be a map, got: #{inspect(cmd_spec)}"
    end

    cmd_path = [cmd_name | cmd_path]

    Enum.each(cmd_spec, fn kv -> check_cmd_spec!(kv, cmd_path) end)
    if args = cmd_spec[:args], do: Enum.each(args, &check_arg_pair!(&1, cmd_path))
    if opts = cmd_spec[:opts], do: Enum.each(opts, &check_opt_pair!(&1, cmd_path))
    if cmds = cmd_spec[:cmds], do: Enum.each(cmds, &check_cmd_pair!(&1, cmd_path))

    :ok
  end

  defp check_cmd_pair!(input, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "expected a {cmd_name, cmd_spec} tuple, got: #{inspect(input)}"
  end

  defp check_cmd_spec!({:help, value}, _cmd_path) when is_binary(value), do: :ok
  defp check_cmd_spec!({:help, value}, _cmd_path) when is_nil(value), do: :ok

  defp check_cmd_spec!({:help, value}, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "expected :help to be a string or nil, got: #{inspect(value)}"
  end

  defp check_cmd_spec!({:args, value}, _cmd_path) when is_list(value), do: :ok

  defp check_cmd_spec!({:args, value}, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "expected :args to be a list, got: #{inspect(value)}"
  end

  defp check_cmd_spec!({:opts, value}, _cmd_path) when is_list(value), do: :ok

  defp check_cmd_spec!({:opts, value}, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "expected :opts to be a list, got: #{inspect(value)}"
  end

  defp check_cmd_spec!({:cmds, value}, _cmd_path) when is_list(value), do: :ok

  defp check_cmd_spec!({:cmds, value}, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "expected :cmds to be a list, got: #{inspect(value)}"
  end

  defp check_cmd_spec!({field, value}, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "unknown field #{inspect(field)} with value #{inspect(value)}"
  end

  defp check_arg_pair!({arg_name, arg_spec}, cmd_path) do
    if not is_atom(arg_name) do
      raise ArgumentError,
            location(cmd_path, :cmd) <>
              "expected arg_name to be an atom, got: " <> inspect(arg_name)
    end

    if not is_map(arg_spec) do
      raise ArgumentError,
            location(cmd_path, :cmd) <>
              "expected arg_spec for " <>
              inspect(arg_name) <>
              " to be a map, got: " <> inspect(arg_spec)
    end

    Enum.each(arg_spec, fn kv -> check_arg_spec!(kv, cmd_path, arg_name) end)
    :ok
  end

  defp check_arg_pair!(input, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "expected a {arg_name, arg_spec} tuple, got: " <> inspect(input)
  end

  defp check_arg_spec!({:help, value}, _cmd_path, _arg_name) when is_binary(value), do: :ok
  defp check_arg_spec!({:help, value}, _cmd_path, _arg_name) when is_nil(value), do: :ok

  defp check_arg_spec!({:help, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :help to be a string or nil, got: #{inspect(value)}"
  end

  @arg_actions value_actions()
  defp check_arg_spec!({:action, value}, _cmd_path, _arg_name) when value in @arg_actions, do: :ok

  defp check_arg_spec!({:action, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :action to be one of #{inspect(@arg_actions)}, got: #{inspect(value)}"
  end

  defp check_arg_spec!({:num_args, value}, cmd_path, arg_name) do
    if check_arg_num_args(value) do
      :ok
    else
      raise ArgumentError,
            location(cmd_path, {:arg, arg_name}) <>
              "expected :num_args to be a positive integer or " <>
              "a {min, max} tuple (min >= 0, max >= 1 or :infinity, min <= max), " <>
              "got: #{inspect(value)}"
    end
  end

  defp check_arg_spec!({:value_name, value}, _cmd_path, _arg_name) when is_binary(value), do: :ok
  defp check_arg_spec!({:value_name, value}, _cmd_path, _arg_name) when is_nil(value), do: :ok

  defp check_arg_spec!({:value_name, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :value_name to be a string or nil, got: #{inspect(value)}"
  end

  @value_parser_sugars [:string, :integer, :float]

  defp check_arg_spec!({:value_parser, value}, _cmd_path, _arg_name)
       when value in @value_parser_sugars,
       do: :ok

  defp check_arg_spec!({:value_parser, {mod, fun}}, _cmd_path, _arg_name)
       when is_atom(mod) and is_atom(fun),
       do: :ok

  defp check_arg_spec!({:value_parser, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :value_parser to be :string, :integer, :float, or a {mod, fun} tuple, got: #{inspect(value)}"
  end

  defp check_arg_spec!({:required, value}, _cmd_path, _arg_name) when is_boolean(value), do: :ok

  defp check_arg_spec!({:required, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :required to be a boolean, got: #{inspect(value)}"
  end

  defp check_arg_spec!({:default_value, value}, _cmd_path, _arg_name) when is_binary(value), do: :ok
  defp check_arg_spec!({:default_value, value}, _cmd_path, _arg_name) when is_nil(value), do: :ok

  defp check_arg_spec!({:default_value, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :default_value to be a string or nil, got: #{inspect(value)}"
  end

  defp check_arg_spec!({field, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "unknown field #{inspect(field)} with value #{inspect(value)}"
  end

  defp check_arg_num_args(n)
       when is_integer(n) and n >= 1,
       do: true

  defp check_arg_num_args({min, max})
       when is_integer(min) and min >= 0 and is_integer(max) and max >= 1,
       do: min <= max

  defp check_arg_num_args({min, :infinity})
       when is_integer(min) and min >= 0,
       do: true

  defp check_arg_num_args(_), do: false

  defp check_opt_pair!({opt_name, opt_spec}, cmd_path) do
    if not is_atom(opt_name) do
      raise ArgumentError,
            location(cmd_path, :cmd) <>
              "expected opt_name to be an atom, got: " <> inspect(opt_name)
    end

    if not is_map(opt_spec) do
      raise ArgumentError,
            location(cmd_path, :cmd) <>
              "expected opt_spec for " <>
              inspect(opt_name) <>
              " to be a map, got: " <> inspect(opt_spec)
    end

    Enum.each(opt_spec, fn kv -> check_opt_spec!(kv, cmd_path, opt_name) end)
    :ok
  end

  defp check_opt_pair!(input, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "expected a {opt_name, opt_spec} tuple, got: " <> inspect(input)
  end

  defp check_opt_spec!({:help, value}, _cmd_path, _opt_name) when is_binary(value), do: :ok
  defp check_opt_spec!({:help, value}, _cmd_path, _opt_name) when is_nil(value), do: :ok

  defp check_opt_spec!({:help, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :help to be a string or nil, got: #{inspect(value)}"
  end

  defp check_opt_spec!({:short, value}, _cmd_path, _opt_name) when is_nil(value), do: :ok

  defp check_opt_spec!({:short, value}, cmd_path, opt_name) when is_binary(value) and byte_size(value) == 1 do
    valid_char? = not String.match?(value, ~r/^[\d\-=\s]$/)

    if valid_char? do
      :ok
    else
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :short to not be a digit, '-', '=', or whitespace, got: #{inspect(value)}"
    end
  end

  defp check_opt_spec!({:short, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :short to be a single-character string or nil, got: #{inspect(value)}"
  end

  defp check_opt_spec!({:long, value}, _cmd_path, _opt_name) when is_nil(value), do: :ok

  defp check_opt_spec!({:long, value}, cmd_path, opt_name) when is_binary(value) and byte_size(value) >= 2 do
    cond do
      String.starts_with?(value, "-") ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                "expected :long to not start with '-', got: #{inspect(value)}"

      String.contains?(value, "=") ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                "expected :long to not contain '=', got: #{inspect(value)}"

      String.match?(value, ~r/\s/) ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                "expected :long to not contain whitespace, got: #{inspect(value)}"

      true ->
        :ok
    end
  end

  defp check_opt_spec!({:long, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :long to be a string of length >= 2 or nil, got: #{inspect(value)}"
  end

  @opt_actions value_actions() ++ flag_actions()
  defp check_opt_spec!({:action, value}, _cmd_path, _opt_name) when value in @opt_actions, do: :ok

  defp check_opt_spec!({:action, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :action to be one of #{inspect(@opt_actions)}, got: #{inspect(value)}"
  end

  defp check_opt_spec!({:num_args, value}, cmd_path, opt_name) do
    if check_opt_num_args(value) do
      :ok
    else
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :num_args to be a non-negative integer or " <>
              "a {min, max} tuple (min >= 0, max >= 0 or :infinity, min <= max), " <>
              "got: #{inspect(value)}"
    end
  end

  defp check_opt_spec!({:value_name, value}, _cmd_path, _opt_name) when is_binary(value), do: :ok
  defp check_opt_spec!({:value_name, value}, _cmd_path, _opt_name) when is_nil(value), do: :ok

  defp check_opt_spec!({:value_name, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :value_name to be a string or nil, got: #{inspect(value)}"
  end

  defp check_opt_spec!({:value_parser, value}, _cmd_path, _opt_name)
       when value in @value_parser_sugars,
       do: :ok

  defp check_opt_spec!({:value_parser, {mod, fun}}, _cmd_path, _opt_name)
       when is_atom(mod) and is_atom(fun),
       do: :ok

  defp check_opt_spec!({:value_parser, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :value_parser to be :string, :integer, :float, or a {mod, fun} tuple, got: #{inspect(value)}"
  end

  defp check_opt_spec!({:required, value}, _cmd_path, _opt_name) when is_boolean(value), do: :ok

  defp check_opt_spec!({:required, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :required to be a boolean, got: #{inspect(value)}"
  end

  defp check_opt_spec!({:default_value, value}, _cmd_path, _opt_name) when is_binary(value), do: :ok
  defp check_opt_spec!({:default_value, value}, _cmd_path, _opt_name) when is_nil(value), do: :ok

  defp check_opt_spec!({:default_value, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :default_value to be a string or nil, got: #{inspect(value)}"
  end

  defp check_opt_spec!({field, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "unknown field #{inspect(field)} with value #{inspect(value)}"
  end

  defp check_opt_num_args(n)
       when is_integer(n) and n >= 0,
       do: true

  defp check_opt_num_args({min, max})
       when is_integer(min) and min >= 0 and is_integer(max) and max >= 0,
       do: min <= max

  defp check_opt_num_args({min, :infinity})
       when is_integer(min) and min >= 0,
       do: true

  defp check_opt_num_args(_), do: false
end
