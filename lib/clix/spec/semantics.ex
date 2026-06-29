defmodule CLIX.SpecNG.Semantics do
  @moduledoc false

  import CLIX.SpecNG, only: [location: 2, flag_actions: 0]

  @flag_actions flag_actions()

  @doc false
  def check!({cmd_name, cmd_spec}, cmd_path) do
    wrapped_cmd_pair = wrap_cmd_pair({cmd_name, cmd_spec})
    check_cmd_pair!(wrapped_cmd_pair, cmd_path)
  end

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

    {cmd_name, cmd_spec}
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
  end

  defp check_at_most_one_unbounded_arg!(args, cmd_path) do
    unbounded = Enum.filter(args, fn {_, spec} -> unbounded?(spec) end)

    if length(unbounded) > 1 do
      [{first_name, _}, {second_name, _} | _] = unbounded

      raise ArgumentError,
            location(cmd_path, :cmd) <>
              "unbounded args #{inspect(first_name)} and #{inspect(second_name)} - at most one is allowed"
    end
  end

  defp check_unbounded_arg_is_last!(args, cmd_path) do
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

  defp check_arg_pair!({arg_name, arg_spec}, cmd_path) do
    check_default_required_conflict!(arg_spec, arg_name, cmd_path, :arg)
    {arg_name, arg_spec}
  end

  defp check_opt_pair!({opt_name, opt_spec}, cmd_path) do
    check_opt_has_short_or_long!(opt_spec, opt_name, cmd_path)
    check_default_required_conflict!(opt_spec, opt_name, cmd_path, :opt)
    check_flag_action_conflicts!(opt_spec, opt_name, cmd_path)
    {opt_name, opt_spec}
  end

  defp check_opt_has_short_or_long!(opt_spec, opt_name, cmd_path) do
    effective_short = unwrap_value(opt_spec.short)
    effective_long = unwrap_value(opt_spec.long)

    if effective_short == nil and effective_long == nil do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :short or :long to be set"
    end
  end

  defp check_default_required_conflict!(spec, name, cmd_path, kind) do
    case {spec.required, spec.default_value} do
      {{:user, true}, {:user, dv}} when dv != nil ->
        raise ArgumentError,
              location(cmd_path, {kind, name}) <>
                ":default_value conflicts with :required: true"

      _ ->
        :ok
    end
  end

  defp check_flag_action_conflicts!(opt_spec, opt_name, cmd_path) do
    case opt_spec.action do
      {:user, action} when action in @flag_actions ->
        check_flag_num_args_conflict!(opt_spec, action, opt_name, cmd_path)
        check_flag_default_value_conflict!(opt_spec, action, opt_name, cmd_path)
        check_flag_value_parser_conflict!(opt_spec, action, opt_name, cmd_path)
        check_flag_value_name_conflict!(opt_spec, action, opt_name, cmd_path)

      _ ->
        :ok
    end
  end

  defp check_flag_num_args_conflict!(opt_spec, action, opt_name, cmd_path) do
    case opt_spec.num_args do
      {:user, n} when n != 0 and n != {0, 0} ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                "flag action #{inspect(action)} conflicts with num_args: #{inspect(n)}"

      _ ->
        :ok
    end
  end

  defp check_flag_default_value_conflict!(opt_spec, action, opt_name, cmd_path) do
    case opt_spec.default_value do
      {:user, dv} when dv != nil ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                "flag action #{inspect(action)} conflicts with default_value: #{inspect(dv)}"

      _ ->
        :ok
    end
  end

  defp check_flag_value_parser_conflict!(opt_spec, action, opt_name, cmd_path) do
    case opt_spec.value_parser do
      {:user, _} ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                "flag action #{inspect(action)} conflicts with value_parser"

      _ ->
        :ok
    end
  end

  defp check_flag_value_name_conflict!(opt_spec, action, opt_name, cmd_path) do
    case opt_spec.value_name do
      {:user, vn} when vn != nil ->
        raise ArgumentError,
              location(cmd_path, {:opt, opt_name}) <>
                "flag action #{inspect(action)} conflicts with value_name: #{inspect(vn)}"

      _ ->
        :ok
    end
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
      action: :set,
      num_args: {1, 1},
      value_name: nil,
      value_parser: :string,
      required: true,
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
      action: :set,
      num_args: {1, 1},
      value_name: nil,
      value_parser: :string,
      required: true,
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

  # TODO
  defp unwrap_pair({name, spec}), do: {name, unwrap_spec(spec)}

  defp unwrap_spec(spec) do
    Map.new(spec, fn {k, v} -> {k, unwrap_value(v)} end)
  end

  defp unwrap_value({:user, v}), do: unwrap_value(v)
  defp unwrap_value({:auto, v}), do: unwrap_value(v)
  defp unwrap_value(pairs) when is_list(pairs), do: Enum.map(pairs, &unwrap_pair/1)
  defp unwrap_value(v), do: v
end
