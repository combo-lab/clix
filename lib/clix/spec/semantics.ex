defmodule CLIX.SpecNG.Semantics do
  @moduledoc false

  alias CLIX.ValueParser
  import CLIX.SpecNG, only: [location: 2, flag_actions: 0, value_actions: 0]

  @value_actions value_actions()
  @flag_actions flag_actions()

  @doc false
  def check!({cmd_name, cmd_spec}, cmd_path) do
    wrapped_cmd_pair = wrap_cmd_pair({cmd_name, cmd_spec})
    check_cmd_pair!(wrapped_cmd_pair, cmd_path)
  end

  defp wrap_cmd_pair({cmd_name, cmd_spec}) do
    default_cmd_spec = %{
      help: nil,
      args: [],
      opts: [],
      cmds: []
    }

    cmd_spec =
      cmd_spec
      |> update_existing(:args, fn args -> Enum.map(args, &wrap_arg_pair/1) end)
      |> update_existing(:opts, fn opts -> Enum.map(opts, &wrap_opt_pair/1) end)
      |> update_existing(:cmds, fn cmds -> Enum.map(cmds, &wrap_cmd_pair/1) end)

    wrapped_cmd_spec = Map.merge(wrap_spec(:auto, default_cmd_spec), wrap_spec(:user, cmd_spec))
    {cmd_name, wrapped_cmd_spec}
  end

  defp update_existing(map, key, fun) do
    case Map.fetch(map, key) do
      {:ok, value} -> Map.put(map, key, fun.(value))
      :error -> map
    end
  end

  defp wrap_arg_pair({arg_name, arg_spec}) do
    default_arg_spec = %{
      help: nil,
      value_name: nil,
      action: :set,
      num_args: {1, 1},
      value_parser: :string,
      required: nil,
      default_value: nil
    }

    wrapped_arg_spec = Map.merge(wrap_spec(:auto, default_arg_spec), wrap_spec(:user, arg_spec))
    {arg_name, wrapped_arg_spec}
  end

  defp wrap_opt_pair({opt_name, opt_spec}) do
    default_opt_spec = %{
      help: nil,
      short: nil,
      long: nil,
      value_name: nil,
      action: :set,
      num_args: {1, 1},
      value_parser: :string,
      required: nil,
      default_value: nil
    }

    wrapped_opt_spec = Map.merge(wrap_spec(:auto, default_opt_spec), wrap_spec(:user, opt_spec))
    {opt_name, wrapped_opt_spec}
  end

  @container_fields [:args, :opts, :cmds]
  defp wrap_spec(tag, spec) when is_map(spec) do
    Map.new(spec, fn {k, v} ->
      if k in @container_fields,
        do: {k, v},
        else: {k, tag_value(tag, v)}
    end)
  end

  @tags [:auto, :user]
  defp tag_value(tag, v) when tag in @tags, do: {tag, v}
  defp untag_value({tag, v}) when tag in @tags, do: v

  defp check_cmd_pair!({cmd_name, cmd_spec}, cmd_path) do
    cmd_path = [cmd_name | cmd_path]

    check_unique_names!(cmd_spec.args, :arg, cmd_path)
    check_unique_names!(cmd_spec.opts, :opt, cmd_path)
    check_unique_names!(cmd_spec.cmds, :cmd, cmd_path)

    check_unique_opt_attr!(cmd_spec.opts, :short, cmd_path)
    check_unique_opt_attr!(cmd_spec.opts, :long, cmd_path)

    check_at_most_one_unbounded_arg!(cmd_spec.args, cmd_path)
    check_unbounded_arg_is_last!(cmd_spec.args, cmd_path)

    Enum.each(cmd_spec.args, &check_arg_pair!(&1, cmd_path))
    Enum.each(cmd_spec.opts, &check_opt_pair!(&1, cmd_path))
    Enum.each(cmd_spec.cmds, &check_cmd_pair!(&1, cmd_path))
    :ok
  end

  # action: :set,
  # num_args: {1, 1},
  # value_parser: :string,
  # required: nil,
  # default_value: nil

  # action: :set,
  # num_args: {1, 1},
  # value_parser: :string,
  # required: nil,
  # default_value: nil

  defp check_arg_pair!({arg_name, arg_spec}, cmd_path) do
    check_conflict_between_action_and_num_args!(:arg, {arg_name, arg_spec}, cmd_path)
    check_conflict_between_num_args_and_required!(:arg, {arg_name, arg_spec}, cmd_path)
    check_conflict_between_required_and_default_value!(:arg, {arg_name, arg_spec}, cmd_path)
    check_default_value_parseability!(:arg, {arg_name, arg_spec}, cmd_path)
    :ok
  end

  defp check_opt_pair!({opt_name, opt_spec}, cmd_path) do
    check_opt_has_short_or_long!({opt_name, opt_spec}, cmd_path)
    check_conflict_between_action_and_num_args!(:opt, {opt_name, opt_spec}, cmd_path)
    check_conflict_between_flag_action_and_others!({opt_name, opt_spec}, cmd_path)
    check_conflict_between_num_args_and_required!(:opt, {opt_name, opt_spec}, cmd_path)
    check_conflict_between_required_and_default_value!(:opt, {opt_name, opt_spec}, cmd_path)
    check_default_value_parseability!(:opt, {opt_name, opt_spec}, cmd_path)
    :ok
  end

  defp check_unique_names!(pairs, kind, cmd_path) do
    Enum.reduce(pairs, MapSet.new(), fn {name, _}, seen ->
      if MapSet.member?(seen, name) do
        raise ArgumentError,
              location(cmd_path, :cmd) <>
                "duplicate #{kind} name #{inspect(name)}"
      else
        MapSet.put(seen, name)
      end
    end)

    :ok
  end

  defp check_unique_opt_attr!(opts, attr, cmd_path) do
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

    :ok
  end

  defp check_at_most_one_unbounded_arg!(args, cmd_path) do
    unbounded_names =
      args
      |> Enum.filter(fn {_, spec} -> unbounded_arg?(spec) end)
      |> Enum.map(fn {name, _} -> name end)

    if length(unbounded_names) > 1 do
      raise ArgumentError,
            location(cmd_path, :cmd) <>
              "unbounded args #{format_arg_names(unbounded_names)} - at most one is allowed"
    end

    :ok
  end

  defp format_arg_names([name]), do: inspect(name)
  defp format_arg_names([a, b]), do: "#{inspect(a)} and #{inspect(b)}"

  defp format_arg_names(names) do
    {rest, [last]} = Enum.split(names, -1)
    "#{Enum.map_join(rest, ", ", &inspect/1)}, and #{inspect(last)}"
  end

  defp check_unbounded_arg_is_last!(args, cmd_path) do
    if length(args) > 1 do
      unbounded = Enum.filter(args, fn {_, spec} -> unbounded_arg?(spec) end)

      if not Enum.empty?(unbounded) do
        {_last_name, last_spec} = List.last(args)

        if not unbounded_arg?(last_spec) do
          [{name, _}] = unbounded

          raise ArgumentError,
                location(cmd_path, :cmd) <>
                  "unbounded arg #{inspect(name)} must be the last arg"
        end
      end
    end

    :ok
  end

  defp unbounded_arg?(wrapped_spec) do
    case wrapped_spec.num_args do
      {:user, {_, :infinity}} -> true
      {:user, _} -> false
      {:auto, _} -> false
    end
  end

  defp check_conflict_between_action_and_num_args!(:arg = kind, {name, spec}, cmd_path) do
    case {spec.action, spec.num_args} do
      {{_, action}, {:user, 0 = num_args}} when action in @value_actions ->
        raise ArgumentError,
              location(cmd_path, {kind, name}) <>
                "num_args: #{inspect(num_args)} conflicts with action #{inspect(action)}"

      {{_, action}, {:user, {min, max} = num_args}} when action in @value_actions and (min == 0 or max == 0) ->
        raise ArgumentError,
              location(cmd_path, {kind, name}) <>
                "num_args: #{inspect(num_args)} conflicts with action #{inspect(action)}"

      _ ->
        :ok
    end
  end

  defp check_conflict_between_action_and_num_args!(:opt = kind, {name, spec}, cmd_path) do
    case {spec.action, spec.num_args} do
      {{_, action}, {:user, 0 = num_args}} when action in @value_actions ->
        raise ArgumentError,
              location(cmd_path, {kind, name}) <>
                "num_args: #{inspect(num_args)} conflicts with action #{inspect(action)}"

      {{_, action}, {:user, {min, max} = num_args}} when action in @value_actions and (min == 0 or max == 0) ->
        raise ArgumentError,
              location(cmd_path, {kind, name}) <>
                "num_args: #{inspect(num_args)} conflicts with action #{inspect(action)}"

      {{_, action}, {:user, num_args}} when action in @flag_actions and num_args not in [0, {0, 0}] ->
        raise ArgumentError,
              location(cmd_path, {kind, name}) <>
                "num_args: #{inspect(num_args)} conflicts with action #{inspect(action)}"

      _ ->
        :ok
    end
  end

  defp check_conflict_between_num_args_and_required!(:arg = kind, {name, spec}, cmd_path) do
    case {spec.num_args, spec.required} do
      {{:user, 0 = num_args}, {:user, true}} ->
        raise ArgumentError,
              location(cmd_path, {kind, name}) <>
                "required: true conflicts with num_args: #{inspect(num_args)} " <>
                "(#{inspect(num_args)} implies required: false)"

      {{:user, {0, _} = num_args}, {:user, true}} ->
        raise ArgumentError,
              location(cmd_path, {kind, name}) <>
                "required: true conflicts with num_args: #{inspect(num_args)} " <>
                "(#{inspect(num_args)} implies required: false)"

      {{:user, num_args}, {:user, false}} when is_integer(num_args) and num_args > 1 ->
        raise ArgumentError,
              location(cmd_path, {kind, name}) <>
                "required: false conflicts with num_args: #{inspect(num_args)} " <>
                "(#{inspect(num_args)} implies required: true)"

      {{:user, {min, _} = num_args}, {:user, false}} when min > 1 ->
        raise ArgumentError,
              location(cmd_path, {kind, name}) <>
                "required: false conflicts with num_args: #{inspect(num_args)} " <>
                "(#{inspect(num_args)} implies required: true)"

      _ ->
        :ok
    end
  end

  defp check_conflict_between_num_args_and_required!(:opt, {_name, _spec}, _cmd_path), do: :ok

  defp check_conflict_between_required_and_default_value!(kind, {name, spec}, cmd_path) do
    case {spec.required, spec.default_value} do
      {{:user, true}, {:user, _}} ->
        raise ArgumentError,
              location(cmd_path, {kind, name}) <>
                ":default_value conflicts with required: true " <>
                "(:default_value implies required: false)"

      _ ->
        :ok
    end
  end

  defp check_opt_has_short_or_long!({opt_name, opt_spec}, cmd_path) do
    effective_short = untag_value(opt_spec.short)
    effective_long = untag_value(opt_spec.long)

    if effective_short == nil and effective_long == nil do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :short or :long to be set"
    end
  end

  defp check_conflict_between_flag_action_and_others!({opt_name, opt_spec}, cmd_path) do
    case opt_spec.action do
      {_, action} when action in @flag_actions ->
        check_conflict_between_flag_action_and_value_name!(action, {opt_name, opt_spec}, cmd_path)
        check_conflict_between_flag_action_and_num_args!(action, {opt_name, opt_spec}, cmd_path)
        check_conflict_between_flag_action_and_value_parser!(action, {opt_name, opt_spec}, cmd_path)
        check_conflict_between_flag_action_and_required!(action, {opt_name, opt_spec}, cmd_path)
        check_conflict_between_flag_action_and_default_value!(action, {opt_name, opt_spec}, cmd_path)
        :ok

      _ ->
        :ok
    end
  end

  defp check_conflict_between_flag_action_and_value_name!(action, {opt_name, opt_spec}, cmd_path) do
    case opt_spec.value_name do
      {:user, _} ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                ":value_name conflicts with action: #{inspect(action)}"

      _ ->
        :ok
    end
  end

  defp check_conflict_between_flag_action_and_num_args!(action, {opt_name, opt_spec}, cmd_path) do
    case opt_spec.num_args do
      {:user, num_args} when num_args not in [0, {0, 0}] ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                "num_args: #{inspect(num_args)} conflicts with action: #{inspect(action)}"

      _ ->
        :ok
    end
  end

  defp check_conflict_between_flag_action_and_value_parser!(action, {opt_name, opt_spec}, cmd_path) do
    case opt_spec.value_parser do
      {:user, _} ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                ":value_parser conflicts with action: #{inspect(action)}"

      _ ->
        :ok
    end
  end

  defp check_conflict_between_flag_action_and_required!(action, {opt_name, opt_spec}, cmd_path) do
    case opt_spec.required do
      {:user, true} ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                "required: true conflicts with action #{inspect(action)}"

      _ ->
        :ok
    end
  end

  defp check_conflict_between_flag_action_and_default_value!(action, {opt_name, opt_spec}, cmd_path) do
    case opt_spec.default_value do
      {:user, _} ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                ":default_value conflicts with action: #{inspect(action)}"

      _ ->
        :ok
    end
  end

  defp check_default_value_parseability!(kind, {name, spec}, cmd_path) do
    case spec.default_value do
      {:user, dv} ->
        {mod, fun} = spec.value_parser |> untag_value() |> ValueParser.resolve_value_parser()

        case apply(mod, fun, [dv]) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            raise ArgumentError,
                  location(cmd_path, {kind, name}) <>
                    "default_value: #{inspect(dv)} cannot be parsed by value_parser: #{inspect({mod, fun})}, " <>
                    "reason: #{reason}"
        end

      _ ->
        :ok
    end
  end
end
