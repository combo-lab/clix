defmodule CLIX.SpecNG do
  @moduledoc """
  The spec builder.

  A spec is the basis for parsing, feedback generation, etc.

  ## Terminology

  This module uses the terms "arg", "opt", "args" and "opts" as described in
  the `CLIX` module documentation. See `CLIX` for details.

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

  @typedoc """
  The command's name.

  The top-level cmd_name is the program name. If you name your CLI app as *example*,
  then you should set the top-level cmd_name as `:example`.
  """
  @type cmd_name :: atom()

  @typedoc "The command's spec."
  @type cmd_spec :: %{
          optional(:help) => help(),
          optional(:args) => [{arg_name(), arg_spec()}],
          optional(:opts) => [{opt_name(), opt_spec()}],
          optional(:cmds) => [{cmd_name(), cmd_spec()}]
        }

  @typedoc "The arg's name."
  @type arg_name :: atom()
  @typedoc "The arg's spec."
  @type arg_spec :: %{
          optional(:help) => help(),
          optional(:action) => arg_action(),
          optional(:num_args) => num_args(),
          optional(:value_name) => value_name(),
          optional(:value_parser) => value_parser(),
          optional(:required) => required(),
          optional(:default_value) => default_value()
        }

  @typedoc "The opt's name."
  @type opt_name :: atom()
  @typedoc "The opt's spec."
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

  @typedoc """
  A brief description shown in help text.
  """
  @type help :: String.t() | nil

  @typedoc """
  The short form of an opt, without the leading dash (e.g. `"v"` for `-v`).

  Must be a single character that is not a digit, `-`, `=`, or whitespace.
  When `nil`, the opt has no short form.
  """
  @type short :: String.t() | nil

  @typedoc """
  The long form of an opt, without the leading dashes (e.g. `"verbose"` for `--verbose`).

  Must be a string of at least 2 characters, not starting with `-`, and not
  containing `=` or whitespace. Internal hyphens are allowed (e.g. `"config-file"`).
  When `nil`, the opt has no long form.
  """
  @type long :: String.t() | nil

  @typedoc """
  How a parsed arg value is stored.

  See `t:value_action/0` for available actions.
  """
  @type arg_action :: value_action()

  @typedoc """
  How a parsed opt value is stored.

  See `t:value_action/0` and `t:flag_action/0` for available actions.
  """
  @type opt_action :: value_action() | flag_action()

  @typedoc """
  Value actions, which consume one or more values:

    * `:set` — replaces the previous value (default).
    * `:append` — appends to a list, allowing the arg or opt to be repeated.

  """
  @type value_action :: :set | :append
  @value_actions [:set, :append]

  @typedoc """
  Flag actions, which consume zero values and bypass `:value_parser`:

    * `:set_true` — sets the value to `true` without consuming a value.
    * `:set_false` — sets the value to `false` without consuming a value.
    * `:count` — increments an integer counter each time the flag appears.

  """
  @type flag_action :: :set_true | :set_false | :count
  @flag_actions [:set_true, :set_false, :count]

  @typedoc """
  The number of values an arg or opt consumes.

  Canonical and sugar forms are provided:

    * `{min, max}` (canonical) — consumes between `min` and `max` values.
    * `n` (sugar) — equivalent to `{n, n}` (exactly `n` values).

  `max` may be `:infinity` for unbounded consumption.

  The acceptable range of `min`/`max` depends on the context:

    * arg: `min >= 0`, `max >= 1`, `min <= max`
    * opt: `min >= 0`, `max >= 0`, `min <= max`

  """
  @type num_args :: num_args_canonical() | num_args_sugar()
  @type num_args_canonical :: {non_neg_integer(), non_neg_integer() | :infinity}
  @type num_args_sugar :: non_neg_integer()

  @typedoc """
  The value placeholder shown in usage and help text (e.g. `<FILE>`).

  When `nil`, CLIX derives one from the arg/opt name.
  """
  @type value_name :: String.t() | nil

  @typedoc """
  The parser that converts a raw string value into a typed value.

  Canonical and sugar forms are provided:

    * `{mod, fun}` (canonical) — refers to `mod.fun/1`.
    * `:string` / `:integer` / `:float` (sugar) — refers to built-in parsers
      defined in `CLIX.ValueParser`.
      For example, `:string` equals to `{CLIX.ValueParser, :string}`.

  The function must accept a `String.t()` and return `{:ok, term()}` on
  success or `{:error, reason :: String.t()}` on failure.

  The error message should be a brief, value-agnostic reason.
  """
  @type value_parser :: value_parser_canonical() | value_parser_sugar()
  @type value_parser_canonical :: {mod :: module(), fun :: atom()}
  @type value_parser_sugar :: :string | :integer | :float

  @typedoc """
  Whether a value must be provided.

  Defaults differ by kind:

    * args: `true`  (args are required by default)
    * opts: `false` (opts are optional by default)

  Setting `:default_value` implicitly sets `:required` to `false`.
  """
  @type required :: boolean()

  @typedoc """
  The fallback value used when the arg or opt is not provided.

  Always a `String.t()`, or `nil` means no default.

  The string goes through `value_parser` at parse time. For example,
  `default_value: "0"` with `value_parser: :integer` yields the integer `0`.
  """
  @type default_value :: String.t() | nil

  @doc """
  Builds a spec from raw data.
  """
  # TODO: replace returned term() with CLIX.Spec.Cmd.t()
  @spec new!(input :: term()) :: term()
  def new!({cmd_name, cmd_spec}) do
    cmd_path = []

    {cmd_name, cmd_spec}
    |> cf_cmd_pair!(cmd_path)
    |> wrap_and_merge_cmd_pair()
    |> cs_cmd_pair!(cmd_path)
    |> unwrap_pair()
    |> normalize_cmd_pair()
  end

  def new!(input) do
    raise ArgumentError,
          location([], :cmd) <>
            "expected a {cmd_name, cmd_spec} tuple, got: #{inspect(input)}"
  end

  ## Checking the format of data
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

    Enum.each(cmd_spec, fn kv -> cf_cmd_spec!(kv, cmd_path) end)
    if args = cmd_spec[:args], do: Enum.each(args, &cf_arg_pair!(&1, cmd_path))
    if opts = cmd_spec[:opts], do: Enum.each(opts, &cf_opt_pair!(&1, cmd_path))
    if cmds = cmd_spec[:cmds], do: Enum.each(cmds, &cf_cmd_pair!(&1, cmd_path))

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

    Enum.each(arg_spec, fn kv -> cf_arg_spec!(kv, cmd_path, arg_name) end)
    :ok
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

  @arg_actions @value_actions
  defp cf_arg_spec!({:action, value}, _cmd_path, _arg_name) when value in @arg_actions, do: :ok

  defp cf_arg_spec!({:action, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :action to be one of #{inspect(@arg_actions)}, got: #{inspect(value)}"
  end

  defp cf_arg_spec!({:num_args, value}, cmd_path, arg_name) do
    if cf_arg_num_args(value) do
      :ok
    else
      raise ArgumentError,
            location(cmd_path, {:arg, arg_name}) <>
              "expected :num_args to be a positive integer or " <>
              "a {min, max} tuple (min >= 0, max >= 1 or :infinity, min <= max), " <>
              "got: #{inspect(value)}"
    end
  end

  defp cf_arg_spec!({:value_name, value}, _cmd_path, _arg_name) when is_binary(value), do: :ok
  defp cf_arg_spec!({:value_name, value}, _cmd_path, _arg_name) when is_nil(value), do: :ok

  defp cf_arg_spec!({:value_name, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :value_name to be a string or nil, got: #{inspect(value)}"
  end

  @value_parser_sugars [:string, :integer, :float]

  defp cf_arg_spec!({:value_parser, value}, _cmd_path, _arg_name)
       when value in @value_parser_sugars,
       do: :ok

  defp cf_arg_spec!({:value_parser, {mod, fun}}, _cmd_path, _arg_name)
       when is_atom(mod) and is_atom(fun),
       do: :ok

  defp cf_arg_spec!({:value_parser, value}, cmd_path, arg_name) do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :value_parser to be :string, :integer, :float, or a {mod, fun} tuple, got: #{inspect(value)}"
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

    Enum.each(opt_spec, fn kv -> cf_opt_spec!(kv, cmd_path, opt_name) end)
    :ok
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

  @opt_actions @value_actions ++ @flag_actions
  defp cf_opt_spec!({:action, value}, _cmd_path, _opt_name) when value in @opt_actions, do: :ok

  defp cf_opt_spec!({:action, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :action to be one of #{inspect(@opt_actions)}, got: #{inspect(value)}"
  end

  defp cf_opt_spec!({:num_args, value}, cmd_path, opt_name) do
    if cf_opt_num_args(value) do
      :ok
    else
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :num_args to be a non-negative integer or " <>
              "a {min, max} tuple (min >= 0, max >= 0 or :infinity, min <= max), " <>
              "got: #{inspect(value)}"
    end
  end

  defp cf_opt_spec!({:value_name, value}, _cmd_path, _opt_name) when is_binary(value), do: :ok
  defp cf_opt_spec!({:value_name, value}, _cmd_path, _opt_name) when is_nil(value), do: :ok

  defp cf_opt_spec!({:value_name, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :value_name to be a string or nil, got: #{inspect(value)}"
  end

  defp cf_opt_spec!({:value_parser, value}, _cmd_path, _opt_name)
       when value in @value_parser_sugars,
       do: :ok

  defp cf_opt_spec!({:value_parser, {mod, fun}}, _cmd_path, _opt_name)
       when is_atom(mod) and is_atom(fun),
       do: :ok

  defp cf_opt_spec!({:value_parser, value}, cmd_path, opt_name) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :value_parser to be :string, :integer, :float, or a {mod, fun} tuple, got: #{inspect(value)}"
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

  ## Wrapping and merging data
  # Merging data, and tags each value as {:user, v} or {:auto, v} for 
  # distinguishing explicit from default.

  defp wrap_and_merge_cmd_pair({cmd_name, cmd_spec}) do
    default_cmd_spec = %{
      help: nil,
      args: [],
      opts: [],
      cmds: []
    }

    cmd_spec =
      cmd_spec
      |> update_map(:args, fn args -> Enum.map(args, &wrap_and_merge_arg_pair/1) end)
      |> update_map(:opts, fn opts -> Enum.map(opts, &wrap_and_merge_opt_pair/1) end)
      |> update_map(:cmds, fn cmds -> Enum.map(cmds, &wrap_and_merge_cmd_pair/1) end)

    cmd_spec = Map.merge(wrap(:auto, default_cmd_spec), wrap(:user, cmd_spec))
    {cmd_name, cmd_spec}
  end

  defp update_map(map, key, value_processor) do
    case Map.fetch(map, key) do
      {:ok, value} -> Map.put(map, key, value_processor.(value))
      :error -> map
    end
  end

  defp wrap_and_merge_arg_pair({arg_name, arg_spec}) do
    default_arg_spec = %{
      help: nil,
      action: :set,
      num_args: {1, 1},
      value_name: nil,
      value_parser: :string,
      required: true,
      default_value: nil
    }

    arg_spec = Map.merge(wrap(:auto, default_arg_spec), wrap(:user, arg_spec))
    {arg_name, arg_spec}
  end

  defp wrap_and_merge_opt_pair({opt_name, opt_spec}) do
    default_opt_spec = %{
      help: nil,
      short: nil,
      long: nil,
      action: :set,
      num_args: {1, 1},
      value_name: nil,
      value_parser: :string,
      required: true,
      default_value: nil
    }

    opt_spec = Map.merge(wrap(:auto, default_opt_spec), wrap(:user, opt_spec))
    {opt_name, opt_spec}
  end

  ## Checking the semantics of data
  # cs_ is the short of check_semantics_.

  defp cs_cmd_pair!({cmd_name, cmd_spec}, cmd_path) do
    cmd_path = [cmd_name | cmd_path]

    cs_unique_names!(cmd_spec.args, :arg, cmd_path)
    cs_unique_names!(cmd_spec.opts, :opt, cmd_path)
    cs_unique_names!(cmd_spec.cmds, :cmd, cmd_path)

    cs_at_most_one_unbounded_arg!(cmd_spec.args, cmd_path)
    cs_unbounded_arg_is_last!(cmd_spec.args, cmd_path)

    cs_unique_opt_attr!(cmd_spec.opts, :short, cmd_path)
    cs_unique_opt_attr!(cmd_spec.opts, :long, cmd_path)

    Enum.each(children(cmd_spec, :args), &cs_arg_pair!(&1, cmd_path))
    Enum.each(children(cmd_spec, :opts), &cs_opt_pair!(&1, cmd_path))
    Enum.each(children(cmd_spec, :cmds), &cs_cmd_pair!(&1, cmd_path))

    {cmd_name, cmd_spec}
  end

  defp children(spec, key), do: untag_value(spec[key])

  defp cs_unique_names!(wrapped_pairs, kind, cmd_path) do
    pairs = untag_value(wrapped_pairs)

    Enum.reduce(pairs, MapSet.new(), fn {name, _}, seen ->
      if MapSet.member?(seen, name) do
        raise ArgumentError,
              location(cmd_path, :cmd) <>
                "duplicate #{kind} name #{inspect(name)}"
      else
        MapSet.put(seen, name)
      end
    end)
  end

  defp cs_unique_opt_attr!(wrapped_opts, attr, cmd_path) do
    opts = untag_value(wrapped_opts)

    Enum.reduce(opts, %{}, fn {opt_name, opt_spec}, seen ->
      case opt_spec[attr] do
        {:user, value} when value != nil ->
          case Map.fetch(seen, value) do
            {:ok, prev_opt_name} ->
              raise ArgumentError,
                    location(cmd_path, :cmd) <>
                      "duplicate #{attr} #{inspect(value)} between " <>
                      "#{inspect(prev_opt_name)} and #{inspect(opt_name)}"

            :error ->
              Map.put(seen, value, opt_name)
          end

        _ ->
          seen
      end
    end)
  end

  defp cs_at_most_one_unbounded_arg!(wrapped_args, cmd_path) do
    args = untag_value(wrapped_args)
    unbounded = Enum.filter(args, fn {_, spec} -> unbounded?(spec) end)

    if length(unbounded) > 1 do
      [{first_name, _}, {second_name, _} | _] = unbounded

      raise ArgumentError,
            location(cmd_path, :cmd) <>
              "unbounded args #{inspect(first_name)} and #{inspect(second_name)} - at most one is allowed"
    end
  end

  defp cs_unbounded_arg_is_last!(wrapped_args, cmd_path) do
    args = untag_value(wrapped_args)

    if length(args) > 1 do
      unbounded = Enum.filter(args, fn {_, spec} -> unbounded?(spec) end)

      if not Enum.empty?(unbounded) do
        {_last_name, last_spec} = List.last(args)

        if not unbounded?(last_spec) do
          [{name, _}] = unbounded

          raise ArgumentError,
                location(cmd_path, :cmd) <>
                  "unbounded arg #{inspect(name)} must be the last arg"
        end
      end
    end
  end

  defp unbounded?(wrapped_spec) do
    case wrapped_spec.num_args do
      {:user, {_, :infinity}} -> true
      {:user, n} when is_integer(n) -> false
      {:user, {_, _}} -> false
      {:auto, _} -> false
    end
  end

  defp cs_arg_pair!({arg_name, arg_spec}, cmd_path) do
    cs_default_required_conflict!(arg_spec, arg_name, cmd_path, :arg)
    {arg_name, arg_spec}
  end

  defp cs_opt_pair!({opt_name, opt_spec}, cmd_path) do
    cs_opt_has_short_or_long!(opt_spec, opt_name, cmd_path)
    cs_default_required_conflict!(opt_spec, opt_name, cmd_path, :opt)
    cs_flag_action_conflicts!(opt_spec, opt_name, cmd_path)
    {opt_name, opt_spec}
  end

  defp cs_opt_has_short_or_long!(opt_spec, opt_name, cmd_path) do
    effective_short = untag_value(opt_spec.short)
    effective_long = untag_value(opt_spec.long)

    if effective_short == nil and effective_long == nil do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :short or :long to be set"
    end
  end

  defp cs_default_required_conflict!(spec, name, cmd_path, kind) do
    case {spec.required, spec.default_value} do
      {{:user, true}, {:user, dv}} when dv != nil ->
        raise ArgumentError,
              location(cmd_path, {kind, name}) <>
                ":default_value conflicts with :required: true"

      _ ->
        :ok
    end
  end

  defp cs_flag_action_conflicts!(opt_spec, opt_name, cmd_path) do
    case opt_spec.action do
      {:user, action} when action in @flag_actions ->
        cs_flag_num_args_conflict!(opt_spec, action, opt_name, cmd_path)
        cs_flag_default_value_conflict!(opt_spec, action, opt_name, cmd_path)
        cs_flag_value_parser_conflict!(opt_spec, action, opt_name, cmd_path)
        cs_flag_value_name_conflict!(opt_spec, action, opt_name, cmd_path)

      _ ->
        :ok
    end
  end

  defp cs_flag_num_args_conflict!(opt_spec, action, opt_name, cmd_path) do
    case opt_spec.num_args do
      {:user, n} when n != 0 and n != {0, 0} ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                "flag action #{inspect(action)} conflicts with num_args: #{inspect(n)}"

      _ ->
        :ok
    end
  end

  defp cs_flag_default_value_conflict!(opt_spec, action, opt_name, cmd_path) do
    case opt_spec.default_value do
      {:user, dv} when dv != nil ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                "flag action #{inspect(action)} conflicts with default_value: #{inspect(dv)}"

      _ ->
        :ok
    end
  end

  defp cs_flag_value_parser_conflict!(opt_spec, action, opt_name, cmd_path) do
    case opt_spec.value_parser do
      {:user, _} ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                "flag action #{inspect(action)} conflicts with value_parser"

      _ ->
        :ok
    end
  end

  defp cs_flag_value_name_conflict!(opt_spec, action, opt_name, cmd_path) do
    case opt_spec.value_name do
      {:user, vn} when vn != nil ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                "flag action #{inspect(action)} conflicts with value_name: #{inspect(vn)}"

      _ ->
        :ok
    end
  end

  ## Normalizing data

  defp normalize_cmd_pair({cmd_name, cmd_pair}) do
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

  defp wrap(tag, map) when is_map(map) and tag in [:auto, :user] do
    Map.new(map, fn {k, v} -> {k, {tag, v}} end)
  end

  defp unwrap_pair({name, spec}), do: {name, unwrap_spec(spec)}

  defp unwrap_spec(wrapped) do
    Map.new(wrapped, fn {k, v} -> {k, unwrap_value(v)} end)
  end

  defp unwrap_value({:user, v}), do: unwrap_inner(v)
  defp unwrap_value({:auto, v}), do: unwrap_inner(v)

  defp untag_value({:user, v}), do: v
  defp untag_value({:auto, v}), do: v

  defp unwrap_inner(children) when is_list(children) do
    Enum.map(children, &unwrap_pair/1)
  end

  defp unwrap_inner(v), do: v
end
