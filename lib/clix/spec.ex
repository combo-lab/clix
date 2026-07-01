defmodule CLIX.Spec do
  @moduledoc false

  @type t :: {cmd_name(), cmd_spec()}

  @type help :: String.t() | nil
  @type summary :: String.t() | nil
  @type description :: String.t() | nil
  @type epilogue :: String.t() | nil

  @type value_name :: String.t() | nil

  @type cmd_name :: atom()
  @type cmd_spec :: %{
          help: help(),
          summary: summary(),
          description: description(),
          cmds: [{cmd_name(), cmd_spec()}],
          args: [{arg_name(), arg_spec()}],
          opts: [{opt_name(), opt_spec()}],
          epilogue: epilogue()
        }

  @typedoc "The type which the argument will be parsed as."
  @type type ::
          :string
          | :boolean
          | :integer
          | :float
          | custom_type()

  @type custom_type ::
          {:custom, (raw_value :: String.t() -> {:ok, value :: term()} | {:error, reason :: String.t()})}
          | {:custom, {module(), atom()}}

  @type nargs :: :! | :"?" | :+ | :*

  @typedoc "The name of a positional argument."
  @type arg_name :: atom()

  @type required_arg_spec ::
          %{
            optional(:help) => help(),
            optional(:type) => type(),
            optional(:nargs) => :!,
            optional(:value_name) => value_name()
          }
          | %{
              optional(:help) => help(),
              optional(:type) => type(),
              :nargs => :+,
              optional(:value_name) => value_name()
            }
  @type optional_arg_spec :: %{
          optional(:help) => help(),
          optional(:type) => type(),
          :nargs => :"?" | :*,
          optional(:default) => any(),
          optional(:value_name) => value_name()
        }
  @typedoc "The parsing spec of a positional argument."
  @type arg_spec :: required_arg_spec() | optional_arg_spec()

  @type short :: String.t() | nil
  @type long :: String.t() | nil
  @type action :: :set | :count | :append

  @typedoc "The name of an option."
  @type opt_name :: atom()

  @type required_opt_spec :: %{
          optional(:short) => short(),
          optional(:long) => long(),
          optional(:type) => type(),
          optional(:action) => action(),
          :required => true,
          optional(:value_name) => value_name(),
          optional(:help) => help()
        }
  @type optional_opt_spec :: %{
          optional(:short) => short(),
          optional(:long) => long(),
          optional(:type) => type(),
          optional(:action) => action(),
          optional(:required) => false,
          optional(:default) => any(),
          optional(:value_name) => value_name(),
          optional(:help) => help()
        }
  @typedoc "The parsing spec of an option."
  @type opt_spec :: required_opt_spec | optional_opt_spec

  @doc """
  Builds a spec from raw spec.

  It will cast and validate the raw spec.
  """
  @spec new(raw_spec :: {cmd_name(), cmd_spec()}) :: t()
  def new({cmd_name, cmd_spec}) when is_atom(cmd_name) and is_map(cmd_spec) do
    cmd_path = []

    {cmd_name, cmd_spec}
    |> cast_cmd_pair()
    |> validate_cmd_pair!(cmd_path)
    |> fill_cmd_spec()
  end

  defp cast_cmd_pair({cmd_name, cmd_spec}) do
    default_cmd_spec = %{
      help: nil,
      summary: nil,
      description: nil,
      cmds: [],
      args: [],
      opts: [],
      epilogue: nil
    }

    cmd_spec =
      default_cmd_spec
      |> Map.merge(cmd_spec)
      |> Map.update!(:args, fn args -> Enum.map(args, &cast_arg_pair(&1)) end)
      |> Map.update!(:opts, fn opts -> Enum.map(opts, &cast_opt_pair(&1)) end)
      # Intentionally placed at the end, because I want to do breadth-first casting.
      |> Map.update!(:cmds, fn cmds -> Enum.map(cmds, &cast_cmd_pair(&1)) end)

    {cmd_name, cmd_spec}
  end

  defp cast_arg_pair({arg_name, arg_spec}) when is_atom(arg_name) and is_map(arg_spec) do
    default_arg_spec = %{
      type: :string,
      nargs: :!,
      value_name: nil,
      help: nil
    }

    arg_spec = Map.merge(default_arg_spec, arg_spec)
    {arg_name, arg_spec}
  end

  defp cast_opt_pair({opt_name, opt_spec}) when is_atom(opt_name) and is_map(opt_spec) do
    default_opt_spec = %{
      short: nil,
      long: nil,
      type: :string,
      action: :set,
      required: false,
      help: nil
    }

    opt_spec = Map.merge(default_opt_spec, opt_spec)
    {opt_name, opt_spec}
  end

  defp validate_cmd_pair!({cmd_name, cmd_spec}, cmd_path) do
    inner_cmd_path = [cmd_name | cmd_path]

    for field <- [:help, :summary, :description, :epilogue] do
      validate_optional_string!(Map.get(cmd_spec, field), field, :cmd, inner_cmd_path)
    end

    validate_unique_names!(cmd_spec.args, :arg, inner_cmd_path)
    validate_unique_names!(cmd_spec.opts, :opt, inner_cmd_path)
    validate_unique_names!(cmd_spec.cmds, :cmd, inner_cmd_path)
    validate_unique_opt_attr!(cmd_spec.opts, :short, inner_cmd_path)
    validate_unique_opt_attr!(cmd_spec.opts, :long, inner_cmd_path)
    validate_at_most_one_unbounded_arg!(cmd_spec.args, inner_cmd_path)

    Enum.each(cmd_spec.args, fn {arg_name, arg_spec} ->
      validate_arg_pair!({arg_name, arg_spec}, inner_cmd_path)
    end)

    Enum.each(cmd_spec.opts, fn {opt_name, opt_spec} ->
      validate_opt_pair!({opt_name, opt_spec}, inner_cmd_path)
    end)

    Enum.each(cmd_spec.cmds, fn {sub_cmd_name, sub_cmd_spec} ->
      validate_cmd_pair!({sub_cmd_name, sub_cmd_spec}, inner_cmd_path)
    end)

    {cmd_name, cmd_spec}
  end

  # Detects duplicate names by scanning in source order, raising on the first
  # collision (so error messages are deterministic for tests).
  defp validate_unique_names!(pairs, kind, cmd_path) do
    Enum.reduce(pairs, MapSet.new(), fn {name, _spec}, seen ->
      if MapSet.member?(seen, name) do
        raise ArgumentError,
              "duplicate #{kind} name #{inspect(name)} under the cmd path #{inspect(Enum.reverse(cmd_path))}"
      else
        MapSet.put(seen, name)
      end
    end)

    :ok
  end

  # Detects two opts sharing the same :short or :long. Same source-order scan.
  defp validate_unique_opt_attr!(opts, attr, cmd_path) do
    Enum.reduce(opts, %{}, fn {opt_name, opt_spec}, seen ->
      case Map.get(opt_spec, attr) do
        nil ->
          seen

        value ->
          case Map.fetch(seen, value) do
            {:ok, prev_opt_name} ->
              raise ArgumentError,
                    "duplicate opt #{inspect(attr)} #{inspect(value)} between " <>
                      "#{inspect(prev_opt_name)} and #{inspect(opt_name)} " <>
                      "under the cmd path #{inspect(Enum.reverse(cmd_path))}"

            :error ->
              Map.put(seen, value, opt_name)
          end
      end
    end)

    :ok
  end

  # Allow at most one positional arg with :nargs in [:*, :+]. Two unbounded
  # nargs make the regex-based slot allocation ambiguous (greedy match would
  # silently give the first one everything). :? is bounded (at most 1 token),
  # so any number of :? args is fine.
  defp validate_at_most_one_unbounded_arg!(args, cmd_path) do
    unbounded = Enum.filter(args, fn {_, %{nargs: n}} -> n in [:*, :+] end)

    if length(unbounded) > 1 do
      [{first_name, %{nargs: first_n}}, {second_name, %{nargs: second_n}} | _] = unbounded

      raise ArgumentError,
            "unbounded args #{inspect(first_name)} (:nargs #{inspect(first_n)}) and " <>
              "#{inspect(second_name)} (:nargs #{inspect(second_n)}) " <>
              "under the cmd path #{inspect(Enum.reverse(cmd_path))} - at most one is allowed"
    end

    :ok
  end

  defp validate_arg_pair!({arg_name, arg_spec}, cmd_path) do
    %{type: type, nargs: nargs} = arg_spec

    validate_optional_string!(Map.get(arg_spec, :help), :help, {:arg, arg_name}, cmd_path)
    validate_optional_string!(Map.get(arg_spec, :value_name), :value_name, {:arg, arg_name}, cmd_path)
    validate_type!(type, {:arg, arg_name}, cmd_path)
    validate_nargs!(nargs, arg_name, cmd_path)

    if Map.has_key?(arg_spec, :default) do
      validate_arg_default!(arg_spec.default, type, nargs, arg_name, cmd_path)
    end
  end

  defp validate_arg_default!(_default, _type, nargs, arg_name, cmd_path) when nargs in [:!, :+] do
    raise ArgumentError,
          location(cmd_path, {:arg, arg_name}) <>
            "expected :default not to be set when :nargs is #{inspect(nargs)}"
  end

  defp validate_arg_default!(default, type, :"?", arg_name, cmd_path) do
    if not default_matches_type?(default, type) do
      raise ArgumentError,
            location(cmd_path, {:arg, arg_name}) <>
              "expected :default to match :type #{inspect(type)}, got: #{inspect(default)}"
    end
  end

  defp validate_arg_default!(default, type, :*, arg_name, cmd_path) do
    if not (is_list(default) and Enum.all?(default, &default_matches_type?(&1, type))) do
      raise ArgumentError,
            location(cmd_path, {:arg, arg_name}) <>
              "expected :default to be a list of :type #{inspect(type)}, got: #{inspect(default)}"
    end
  end

  defp validate_opt_pair!({opt_name, opt_spec}, cmd_path) do
    %{short: short, long: long} = opt_spec

    validate_optional_string!(Map.get(opt_spec, :help), :help, {:opt, opt_name}, cmd_path)
    validate_optional_string!(Map.get(opt_spec, :value_name), :value_name, {:opt, opt_name}, cmd_path)

    unless is_boolean(opt_spec.required) do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :required to be a boolean, got: #{inspect(opt_spec.required)}"
    end

    if short == nil and long == nil do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :short or :long to be set"
    end

    if short && String.length(short) !== 1 do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :short to be an one-char string, got: #{inspect(short)}"
    end

    if long && String.length(long) == 1 do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :long to be a multi-chars string, got: #{inspect(long)}"
    end

    if short && short =~ ~r/^[\d\-=\s]$/ do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :short to not be a digit, \"-\", \"=\", or whitespace, got: #{inspect(short)}"
    end

    if long && String.starts_with?(long, "-") do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :long to not start with '-', got: #{inspect(long)}"
    end

    if long && String.contains?(long, "=") do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :long to not contain '=', got: #{inspect(long)}"
    end

    %{type: type, action: action} = opt_spec

    validate_type!(type, {:opt, opt_name}, cmd_path)
    validate_action!(action, opt_name, cmd_path)

    if action == :count and type !== :boolean do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :type to be :boolean when :action is :count, got: #{inspect(type)}"
    end

    if Map.has_key?(opt_spec, :default) do
      validate_opt_default!(opt_spec.default, type, action, opt_spec.required, opt_name, cmd_path)
    end
  end

  defp validate_opt_default!(_default, _type, _action, true = _required, opt_name, cmd_path) do
    raise ArgumentError,
          location(cmd_path, {:opt, opt_name}) <>
            "expected :default not to be set when :required is true"
  end

  defp validate_opt_default!(default, type, :set, false, opt_name, cmd_path) do
    if not default_matches_type?(default, type) do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :default to match :type #{inspect(type)}, got: #{inspect(default)}"
    end
  end

  defp validate_opt_default!(default, _type, :count, false, opt_name, cmd_path) do
    if not is_integer(default) do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :default to be an integer when :action is :count, got: #{inspect(default)}"
    end
  end

  defp validate_opt_default!(default, type, :append, false, opt_name, cmd_path) do
    if not (is_list(default) and Enum.all?(default, &default_matches_type?(&1, type))) do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :default to be a list of :type #{inspect(type)}, got: #{inspect(default)}"
    end
  end

  defp default_matches_type?(nil, _type), do: true
  defp default_matches_type?(value, :string), do: is_binary(value)
  defp default_matches_type?(value, :boolean), do: is_boolean(value)
  defp default_matches_type?(value, :integer), do: is_integer(value)
  defp default_matches_type?(value, :float), do: is_float(value)
  # :custom returns user-defined types; can't statically check, so trust the user.
  defp default_matches_type?(_value, {:custom, _}), do: true

  defp location(cmd_path, :cmd) when is_list(cmd_path) do
    "under the cmd path #{inspect(Enum.reverse(cmd_path))} - "
  end

  defp location(cmd_path, {:arg, arg_name}) when is_list(cmd_path) do
    "arg #{inspect(arg_name)} under the cmd path #{inspect(Enum.reverse(cmd_path))} - "
  end

  defp location(cmd_path, {:opt, opt_name}) when is_list(cmd_path) do
    "opt #{inspect(opt_name)} under the cmd path #{inspect(Enum.reverse(cmd_path))} - "
  end

  defp validate_optional_string!(value, _field, _name_tag, _cmd_path) when is_nil(value) or is_binary(value), do: :ok

  defp validate_optional_string!(value, field, name_tag, cmd_path) do
    raise ArgumentError,
          location(cmd_path, name_tag) <>
            "expected #{inspect(field)} to be a string or nil, got: #{inspect(value)}"
  end

  defp validate_type!(type, name_tag, cmd_path) do
    case type do
      t when t in [:string, :boolean, :integer, :float] ->
        :ok

      {:custom, fun} when is_function(fun, 1) ->
        :ok

      {:custom, {mod, fun}} when is_atom(mod) and is_atom(fun) ->
        :ok

      _ ->
        raise ArgumentError,
              location(cmd_path, name_tag) <>
                "expected :type to be one of " <>
                "[:string, :boolean, :integer, :float, {:custom, fun}, " <>
                "{:custom, {mod, fun}}], " <>
                "got: #{inspect(type)}"
    end
  end

  defp validate_nargs!(nargs, arg_name, cmd_path) do
    if nargs not in [:!, :"?", :+, :*] do
      raise ArgumentError,
            location(cmd_path, {:arg, arg_name}) <>
              "expected :nargs to be one of [:!, :\"?\", :+, :*], got: #{inspect(nargs)}"
    end
  end

  defp validate_action!(action, opt_name, cmd_path) do
    if action not in [:set, :count, :append] do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :action to be one of [:set, :count, :append], got: #{inspect(action)}"
    end
  end

  defp fill_cmd_spec({cmd_name, cmd_spec}) do
    cmd_spec =
      cmd_spec
      |> put_cmd_help()
      |> Map.update!(:args, fn args ->
        Enum.map(args, fn {arg_name, arg_spec} ->
          {arg_name, arg_spec |> put_arg_default() |> put_arg_value_name(arg_name)}
        end)
      end)
      |> Map.update!(:opts, fn opts ->
        Enum.map(opts, fn {opt_name, opt_spec} ->
          {opt_name, opt_spec |> put_opt_default() |> put_opt_value_name(opt_name)}
        end)
      end)
      |> Map.update!(:cmds, fn cmds -> Enum.map(cmds, &fill_cmd_spec(&1)) end)

    {cmd_name, cmd_spec}
  end

  # DONE
  defp put_cmd_help(%{help: nil} = cmd_spec), do: Map.put(cmd_spec, :help, cmd_spec.summary)
  defp put_cmd_help(cmd_spec), do: cmd_spec

  # DONE
  defp put_arg_value_name(%{value_name: value_name} = arg_spec, _arg_name) when value_name !== nil do
    arg_spec
  end

  # DONE
  defp put_arg_value_name(arg_spec, arg_name) do
    Map.put(arg_spec, :value_name, arg_name |> to_string() |> String.upcase())
  end

  # DONE
  defp put_opt_value_name(%{value_name: value_name} = opt_spec, _opt_name) when value_name !== nil do
    opt_spec
  end

  # DONE
  defp put_opt_value_name(opt_spec, opt_name) do
    Map.put(opt_spec, :value_name, opt_name |> to_string() |> String.upcase())
  end

  defp put_arg_default(%{nargs: :!} = arg_spec), do: arg_spec

  defp put_arg_default(%{nargs: :"?", default: _} = arg_spec), do: arg_spec
  defp put_arg_default(%{nargs: :"?"} = arg_spec), do: Map.put(arg_spec, :default, nil)

  defp put_arg_default(%{nargs: :+} = arg_spec), do: arg_spec

  defp put_arg_default(%{nargs: :*, default: _} = arg_spec), do: arg_spec
  defp put_arg_default(%{nargs: :*} = arg_spec), do: Map.put(arg_spec, :default, [])

  defp put_opt_default(%{action: :set, type: :boolean, required: true} = opt_spec), do: opt_spec
  defp put_opt_default(%{action: :set, type: :boolean, required: false, default: _} = opt_spec), do: opt_spec
  defp put_opt_default(%{action: :set, type: :boolean, required: false} = opt_spec), do: Map.put(opt_spec, :default, false)

  defp put_opt_default(%{action: :set, type: _, required: true} = opt_spec), do: opt_spec
  defp put_opt_default(%{action: :set, type: _, required: false, default: _} = opt_spec), do: opt_spec
  defp put_opt_default(%{action: :set, type: _, required: false} = opt_spec), do: Map.put(opt_spec, :default, nil)

  defp put_opt_default(%{action: :count, type: _, required: true} = opt_spec), do: opt_spec
  defp put_opt_default(%{action: :count, type: _, required: false, default: _} = opt_spec), do: opt_spec
  defp put_opt_default(%{action: :count, type: _, required: false} = opt_spec), do: Map.put(opt_spec, :default, 0)

  defp put_opt_default(%{action: :append, type: _, required: true} = opt_spec), do: opt_spec
  defp put_opt_default(%{action: :append, type: _, required: false, default: _} = opt_spec), do: opt_spec
  defp put_opt_default(%{action: :append, type: _, required: false} = opt_spec), do: Map.put(opt_spec, :default, [])

  @doc false
  @spec compact_cmd_spec(t(), [atom()]) :: cmd_spec()
  def compact_cmd_spec({_cmd_name, cmd_spec}, subcmd_path) do
    do_compact_cmd_spec(cmd_spec, subcmd_path, {[], []})
  end

  defp do_compact_cmd_spec(cmd_spec, [], {args, opts}) do
    %{args: new_args, opts: new_opts} = cmd_spec
    args = [new_args | args]
    opts = [new_opts | opts]

    cmd_spec
    |> Map.put(:args, args |> Enum.reverse() |> List.flatten())
    |> Map.put(:opts, opts |> Enum.reverse() |> List.flatten())
  end

  defp do_compact_cmd_spec(cmd_spec, [subcmd | rest], {args, opts}) do
    %{args: new_args, opts: new_opts} = cmd_spec
    args = [new_args | args]
    opts = [new_opts | opts]
    subcmd_spec = cmd_spec |> Map.fetch!(:cmds) |> Keyword.fetch!(subcmd)
    do_compact_cmd_spec(subcmd_spec, rest, {args, opts})
  end
end
