defmodule CLIX.SpecNG do
  @moduledoc """
  The spec builder.

  A spec is the basis for parsing, feedback generation, etc.

  ## Building at compile time

  `new!/1` checks the format and validates the semantics of input eagerly, then
  returns a finalized spec. For the cases where the spec is fixed, you can pay
  the cost once at compile time by assigning the result to a module attribute:

    defmodule MyCLI do
      @cli_spec CLIX.Spec.new!({:my_cli,
                 %{
                   # ...
                 }})
    end

  Elixir evaluates the right-hand side of `@cli_spec` when the module is
  compiled and inlines the resulting spec wherever `@cli_spec` is referenced.

  An invalid spec will fail `mix compile` with the same `ArgumentError` you'd
  see at runtime.

  """

  @type cmd_name :: atom()
  @type cmd_spec :: %{
          optional(:help) => help(),
          optional(:args) => [{arg_name(), arg_spec()}],
          optional(:opts) => [{opt_name(), opt_spec()}],
          optional(:cmds) => [{cmd_name(), cmd_spec()}]
        }

  @type arg_name :: atom()
  @type arg_spec :: %{
          optional(:help) => help(),
          optional(:action) => arg_action(),
          optional(:num_args) => num_args(),
          optional(:value_name) => value_name(),
          optional(:value_parser) => value_parser(),
          optional(:required) => required(),
          optional(:default_value) => default_value()
        }

  @type opt_name :: atom()
  @type opt_spec :: %{
          optional(:help) => help(),
          optional(:short) => short(),
          optional(:long) => long(),
          optional(:action) => opt_action(),
          optional(:num_args) => num_args(),
          optional(:value_name) => value_name(),
          optional(:value_parser) => value_parser(),
          optional(:required) => required(),
          optional(:default_value) => default_value()
        }

  @type help :: String.t() | nil

  @type short :: String.t() | nil
  @type long :: String.t() | nil

  @type arg_action :: :set | :append
  @type opt_action :: :set | :append | :set_true | :set_false | :count

  @type num_args :: {non_neg_integer(), non_neg_integer() | :infinity} | non_neg_integer()

  @type value_name :: String.t() | nil
  @type value_parser :: {mod :: module(), args :: list()}
  @type required :: boolean()
  @type default_value :: String.t() | nil

  @doc """
  Builds a spec from raw data.
  """
  # TODO: replace term() with CLIX.Spec.Cmd.t()
  @spec new!(raw :: {cmd_name(), cmd_spec()}) :: term()
  def new!({cmd_name, cmd_spec}) do
    cmd_path = []

    {cmd_name, cmd_spec}
    |> cf_cmd_pair!(cmd_path)
  end

  ## Check the format of spec

  # cf_ is the short of check_format_.
  defp cf_cmd_pair!({cmd_name, cmd_spec}, cmd_path) do
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

    default_cmd_spec = %{
      help: nil,
      args: [],
      opts: [],
      cmds: []
    }

    cmd_spec = Map.merge(default_cmd_spec, cmd_spec)

    Enum.each(cmd_spec, fn kv -> cf_cmd_spec!(kv, cmd_path) end)
    Enum.each(cmd_spec.args, &cf_arg_pair!(&1, cmd_path))
    Enum.each(cmd_spec.opts, &cf_opt_pair!(&1, cmd_path))
    Enum.each(cmd_spec.cmds, &cf_cmd_pair!(&1, cmd_path))

    {cmd_name, cmd_spec}
  end

  defp cf_cmd_pair!(input, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "expected a {cmd_name, cmd_spec} tuple, got: #{inspect(input)}"
  end

  defp cf_cmd_spec!({:help, value}, _cmd_path) when is_binary(value), do: :ok
  defp cf_cmd_spec!({:help, value}, _cmd_path) when is_nil(value), do: :ok

  defp cf_cmd_spec!({:help, value}, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "expected :help to be a string or nil, got: #{inspect(value)}"
  end

  defp cf_cmd_spec!({:args, value}, _cmd_path) when is_list(value), do: :ok

  defp cf_cmd_spec!({:args, value}, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "expected :args to be a list, got: #{inspect(value)}"
  end

  defp cf_cmd_spec!({:opts, value}, _cmd_path) when is_list(value), do: :ok

  defp cf_cmd_spec!({:opts, value}, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "expected :opts to be a list, got: #{inspect(value)}"
  end

  defp cf_cmd_spec!({:cmds, value}, _cmd_path) when is_list(value), do: :ok

  defp cf_cmd_spec!({:cmds, value}, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "expected :cmds to be a list, got: #{inspect(value)}"
  end

  defp cf_cmd_spec!({field, value}, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "unknown field #{inspect(field)} with value #{inspect(value)}"
  end

  defp cf_arg_pair!({arg_name, arg_spec}, cmd_path) do
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

    default_arg_spec = %{
      help: nil,
      action: :set,
      num_args: {1, 1},
      value_name: nil,
      # TODO: use the parser for string
      # value_parser: ?,
      required: true,
      default_value: nil
    }

    arg_spec = Map.merge(default_arg_spec, arg_spec)
    Enum.each(arg_spec, fn kv -> cf_arg_spec!(kv, cmd_path, arg_name) end)
    {arg_name, arg_spec}
  end

  defp cf_arg_pair!(input, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "expected a {arg_name, arg_spec} tuple, got: " <> inspect(input)
  end

  defp cf_arg_spec!({:help, value}, _cmd_path, _arg_name) when is_binary(value), do: :ok
  defp cf_arg_spec!({:help, value}, _cmd_path, _arg_name) when is_nil(value), do: :ok

  defp cf_arg_spec!({:help, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :help to be a string or nil, got: #{inspect(value)}"
  end

  @arg_valid_actions [:set, :append]
  defp cf_arg_spec!({:action, value}, _cmd_path, _arg_name) when value in @arg_valid_actions, do: :ok

  defp cf_arg_spec!({:action, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :action to be one of #{inspect(@arg_valid_actions)}, got: #{inspect(value)}"
  end

  defp cf_arg_spec!({:num_args, value}, cmd_path, arg_name) do
    if cf_arg_num_args(value) do
      :ok
    else
      raise ArgumentError,
            location(cmd_path, {:arg, arg_name}) <>
              "expected :num_args to be a positive integer, or a {min, max} tuple where " <>
              "min >= 0 and max >= 1 or :infinity, got: #{inspect(value)}"
    end
  end

  defp cf_arg_spec!({:value_name, value}, _cmd_path, _arg_name) when is_binary(value), do: :ok
  defp cf_arg_spec!({:value_name, value}, _cmd_path, _arg_name) when is_nil(value), do: :ok

  defp cf_arg_spec!({:value_name, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :value_name to be a string or nil, got: #{inspect(value)}"
  end

  defp cf_arg_spec!({:value_parser, {mod, args}}, _cmd_path, _arg_name)
       when is_atom(mod) and is_list(args),
       do: :ok

  defp cf_arg_spec!({:value_parser, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :value_parser to be a {module(), args :: list()} tuple, got: #{inspect(value)}"
  end

  defp cf_arg_spec!({:required, value}, _cmd_path, _arg_name) when is_boolean(value), do: :ok

  defp cf_arg_spec!({:required, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :required to be a boolean, got: #{inspect(value)}"
  end

  defp cf_arg_spec!({:default_value, value}, _cmd_path, _arg_name) when is_binary(value), do: :ok
  defp cf_arg_spec!({:default_value, value}, _cmd_path, _arg_name) when is_nil(value), do: :ok

  defp cf_arg_spec!({:default_value, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :default_value to be a string or nil, got: #{inspect(value)}"
  end

  defp cf_arg_spec!({field, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "unknown field #{inspect(field)} with value #{inspect(value)}"
  end

  defp cf_arg_num_args(n)
       when is_integer(n) and n >= 1,
       do: true

  defp cf_arg_num_args({min, max})
       when is_integer(min) and min >= 0 and is_integer(max) and max >= 1,
       do: min <= max

  defp cf_arg_num_args({min, :infinity})
       when is_integer(min) and min >= 0,
       do: true

  defp cf_arg_num_args(_), do: false

  defp cf_opt_pair!({opt_name, opt_spec}, cmd_path) do
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

    default_opt_spec = %{
      help: nil,
      short: nil,
      long: nil,
      action: :set,
      num_args: {1, 1},
      value_name: nil,
      # TODO: use the parser for string
      # value_parser: ?,
      required: true,
      default_value: nil
    }

    opt_spec = Map.merge(default_opt_spec, opt_spec)
    Enum.each(opt_spec, fn kv -> cf_opt_spec!(kv, cmd_path, opt_name) end)
    {opt_name, opt_spec}
  end

  defp cf_opt_pair!(input, cmd_path) do
    raise ArgumentError,
          location(cmd_path, :cmd) <>
            "expected a {opt_name, opt_spec} tuple, got: " <> inspect(input)
  end

  defp cf_opt_spec!({:help, value}, _cmd_path, _opt_name) when is_binary(value), do: :ok
  defp cf_opt_spec!({:help, value}, _cmd_path, _opt_name) when is_nil(value), do: :ok

  defp cf_opt_spec!({:help, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :help to be a string or nil, got: #{inspect(value)}"
  end

  defp cf_opt_spec!({:short, value}, _cmd_path, _opt_name) when is_nil(value), do: :ok

  defp cf_opt_spec!({:short, value}, cmd_path, opt_name) when is_binary(value) and byte_size(value) == 1 do
    valid_char? = not String.match?(value, ~r/^[\d\-=\s]$/)

    if valid_char? do
      :ok
    else
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :short to not be a digit, '-', '=', or whitespace, got: #{inspect(value)}"
    end
  end

  defp cf_opt_spec!({:short, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :short to be a single-character string or nil, got: #{inspect(value)}"
  end

  defp cf_opt_spec!({:long, value}, _cmd_path, _opt_name) when is_nil(value), do: :ok

  defp cf_opt_spec!({:long, value}, cmd_path, opt_name) when is_binary(value) and byte_size(value) >= 2 do
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

  defp cf_opt_spec!({:long, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :long to be a string of length >= 2 or nil, got: #{inspect(value)}"
  end

  @opt_valid_actions [:set, :append, :set_true, :set_false, :count]
  defp cf_opt_spec!({:action, value}, _cmd_path, _opt_name) when value in @opt_valid_actions, do: :ok

  defp cf_opt_spec!({:action, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :action to be one of #{inspect(@opt_valid_actions)}, got: #{inspect(value)}"
  end

  defp cf_opt_spec!({:num_args, value}, cmd_path, opt_name) do
    if cf_opt_num_args(value) do
      :ok
    else
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :num_args to be a non-negative integer, or a {min, max} tuple where " <>
              "min >= 0 and max >= 0 or :infinity, got: #{inspect(value)}"
    end
  end

  defp cf_opt_spec!({:value_name, value}, _cmd_path, _opt_name) when is_binary(value), do: :ok
  defp cf_opt_spec!({:value_name, value}, _cmd_path, _opt_name) when is_nil(value), do: :ok

  defp cf_opt_spec!({:value_name, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :value_name to be a string or nil, got: #{inspect(value)}"
  end

  defp cf_opt_spec!({:value_parser, {mod, args}}, _cmd_path, _opt_name)
       when is_atom(mod) and is_list(args),
       do: :ok

  defp cf_opt_spec!({:value_parser, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :value_parser to be a {module(), args :: list()} tuple, got: #{inspect(value)}"
  end

  defp cf_opt_spec!({:required, value}, _cmd_path, _opt_name) when is_boolean(value), do: :ok

  defp cf_opt_spec!({:required, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :required to be a boolean, got: #{inspect(value)}"
  end

  defp cf_opt_spec!({:default_value, value}, _cmd_path, _opt_name) when is_binary(value), do: :ok
  defp cf_opt_spec!({:default_value, value}, _cmd_path, _opt_name) when is_nil(value), do: :ok

  defp cf_opt_spec!({:default_value, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :default_value to be a string or nil, got: #{inspect(value)}"
  end

  defp cf_opt_spec!({field, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "unknown field #{inspect(field)} with value #{inspect(value)}"
  end

  defp cf_opt_num_args(n)
       when is_integer(n) and n >= 0,
       do: true

  defp cf_opt_num_args({min, max})
       when is_integer(min) and min >= 0 and is_integer(max) and max >= 0,
       do: min <= max

  defp cf_opt_num_args({min, :infinity})
       when is_integer(min) and min >= 0,
       do: true

  defp cf_opt_num_args(_), do: false

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

  # defp validate_num_args({min, max}) do
  #   min >= 0 and min <= max
  # end

  ## 

  defp location(cmd_path, :cmd) when is_list(cmd_path) do
    "under the cmd path #{inspect(Enum.reverse(cmd_path))} - "
  end

  defp location(cmd_path, {:arg, arg_name}) when is_list(cmd_path) do
    "arg #{inspect(arg_name)} under the cmd path #{inspect(Enum.reverse(cmd_path))} - "
  end

  defp location(cmd_path, {:opt, opt_name}) when is_list(cmd_path) do
    "opt #{inspect(opt_name)} under the cmd path #{inspect(Enum.reverse(cmd_path))} - "
  end
end
