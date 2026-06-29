defmodule CLIX.SpecNG.SemanticsTest do
  use ExUnit.Case, async: true

  alias CLIX.SpecNG.Types
  alias CLIX.SpecNG.Semantics

  defp new!({cmd_name, cmd_spec}) do
    cmd_path = []
    Types.check!({cmd_name, cmd_spec}, cmd_path)
    Semantics.check!({cmd_name, cmd_spec}, cmd_path)
    {cmd_name, cmd_spec}
  end

  defp spec(overrides) when is_map(overrides) do
    new!({:example, overrides})
  end

  defp arg(overrides) when is_map(overrides) do
    spec(%{args: [file: overrides]})
  end

  defp opt(overrides) when is_map(overrides) do
    spec(%{opts: [mode: Map.merge(%{short: "m"}, overrides)]})
  end

  describe "structural constraints - duplicate names -" do
    test "duplicate arg names are rejected" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - duplicate arg name :file",
                   fn -> spec(%{args: [file: %{}, file: %{num_args: {0, 1}}]}) end
    end

    test "duplicate opt names are rejected" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - duplicate opt name :mode",
                   fn -> spec(%{opts: [mode: %{short: "m"}, mode: %{short: "n"}]}) end
    end

    test "duplicate cmd names are rejected" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - duplicate cmd name :sub",
                   fn -> spec(%{cmds: [sub: %{}, sub: %{}]}) end
    end

    test "arg, opt, and cmd can share the same name" do
      assert {_, _} =
               spec(%{
                 args: [shared: %{}],
                 opts: [shared: %{short: "s"}],
                 cmds: [shared: %{}]
               })
    end
  end

  describe "structural constraints - duplicate short/long -" do
    test "duplicate short is rejected" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - duplicate short \"v\" between :verbose and :version",
                   fn ->
                     spec(%{opts: [verbose: %{short: "v"}, version: %{short: "v"}]})
                   end
    end

    test "duplicate long is rejected" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - duplicate long \"verbose\" between :verbose and :version",
                   fn ->
                     spec(%{opts: [verbose: %{long: "verbose"}, version: %{long: "verbose"}]})
                   end
    end

    test "same short across different cmds is OK" do
      assert {_, _} =
               spec(%{
                 cmds: [
                   sub1: %{opts: [mode: %{short: "m"}]},
                   sub2: %{opts: [mode: %{short: "m"}]}
                 ]
               })

      assert {_, _} =
               spec(%{
                 cmds: [
                   sub1: %{opts: [mode: %{long: "mode"}]},
                   sub2: %{opts: [mode: %{long: "mode"}]}
                 ]
               })
    end
  end

  describe "structural constraints - unbounded args -" do
    test "single unbounded arg is OK" do
      assert {_, _} = spec(%{args: [a: %{num_args: {1, :infinity}}]})
    end

    test "bounded args is OK" do
      assert {_, _} = spec(%{args: [a: %{num_args: {0, 2}}, b: %{num_args: {0, 3}}]})
    end

    test "one unbounded arg at the end is OK" do
      assert {_, _} = spec(%{args: [a: %{num_args: 1}, b: %{num_args: {1, :infinity}}]})
    end

    test "must be at most one" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - unbounded args :a and :b - at most one is allowed",
                   fn ->
                     spec(%{args: [a: %{num_args: {1, :infinity}}, b: %{num_args: {1, :infinity}}]})
                   end

      assert_raise ArgumentError,
                   "under the cmd path [:example] - unbounded args :a, :b, and :c - at most one is allowed",
                   fn ->
                     spec(%{
                       args: [
                         a: %{num_args: {1, :infinity}},
                         b: %{num_args: {1, :infinity}},
                         c: %{num_args: {0, :infinity}}
                       ]
                     })
                   end
    end

    test "must be the last arg" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - unbounded arg :a must be the last arg",
                   fn ->
                     spec(%{args: [a: %{num_args: {1, :infinity}}, b: %{num_args: 1}]})
                   end
    end
  end

  describe "field conflicts - arg -" do
    test "num_args: <set> (zero) is rejected" do
      # checked by types checker
    end

    test "required: true + default_value: <unset> is accepted" do
      assert {_, _} = arg(%{required: true})
    end

    test "required: true + default_value: <set> is rejected" do
      assert_raise ArgumentError,
                   "arg :file under the cmd path [:example] - :default_value conflicts with required: true",
                   fn -> arg(%{required: true, default_value: "x"}) end
    end

    test "required: false + default_value: <unset> is accepted" do
      assert {_, _} = arg(%{required: false})
    end

    test "required: false + default_value: <set> is accepted" do
      assert {_, _} = arg(%{required: false, default_value: "x"})
    end

    test "required: <unset> + default_value: <set> is accepted" do
      assert {_, _} = arg(%{default_value: "x"})
    end
  end

  describe "field conflicts - opt -" do
    test "short: <unset> + long: <unset> is rejected" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :short or :long to be set",
                   fn -> spec(%{opts: [mode: %{}]}) end
    end

    test "required: true + default_value: <set> is rejected" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - :default_value conflicts with required: true",
                   fn -> opt(%{required: true, default_value: "x"}) end
    end

    test "flag action + minimal fields is accepted" do
      assert {_, _} = spec(%{opts: [verbose: %{short: "v", action: :set_true}]})
      assert {_, _} = spec(%{opts: [quiet: %{long: "quiet", action: :set_false}]})
      assert {_, _} = spec(%{opts: [count: %{short: "c", action: :count}]})
    end

    test "flag action + value_name: <set> is rejected" do
      for a <- [:set_true, :set_false, :count] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - :value_name conflicts with action: #{inspect(a)}",
                     fn -> opt(%{action: a, value_name: "FILE"}) end
      end
    end

    test "flag action + value_name: <unset> is accepted" do
      for a <- [:set_true, :set_false, :count] do
        assert {_, _} = opt(%{action: a})
      end
    end

    test "flag action + num_args: <set> (not zero) is rejected" do
      for a <- [:set_true, :set_false, :count],
          n <- [1, 2, {1, 1}, {0, 1}, {1, :infinity}] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - num_args: #{inspect(n)} conflicts with action: #{inspect(a)}",
                     fn -> opt(%{action: a, num_args: n}) end
      end
    end

    test "flag action + num_args: <set> (zero) is accepted" do
      assert {_, _} = opt(%{action: :count, num_args: 0})
      assert {_, _} = opt(%{action: :count, num_args: {0, 0}})
    end

    test "flag action + num_args: <unset> is accepted" do
      for a <- [:set_true, :set_false, :count] do
        assert {_, _} = opt(%{action: a})
      end
    end

    test "flag action + value_parser: <set> is rejected" do
      for a <- [:set_true, :set_false, :count] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - :value_parser conflicts with action: #{inspect(a)}",
                     fn -> opt(%{action: a, value_parser: :string}) end
      end
    end

    test "flag action + value_parser: <unset> is accepted" do
      for a <- [:set_true, :set_false, :count] do
        assert {_, _} = opt(%{action: a})
      end
    end

    test "flag action + default_value: <set> is rejected" do
      for a <- [:set_true, :set_false, :count] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - :default_value conflicts with action: #{inspect(a)}",
                     fn -> opt(%{action: a, default_value: "x"}) end
      end
    end

    test "value action + num_args: <set> is OK" do
      assert {_, _} = opt(%{action: :set, num_args: 2})
      assert {_, _} = opt(%{action: :append, num_args: {1, :infinity}})
    end

    test "value action + value_parser: <set> + default_value: <set> is accepted" do
      for a <- [:set, :append] do
        assert {_, _} = opt(%{action: a, value_parser: :integer, default_value: "0"})
      end
    end
  end

  describe "nested cmds - semantics are validated recursively -" do
    test "duplicate arg names in nested cmd are rejected" do
      assert_raise ArgumentError,
                   "under the cmd path [:example, :subcmd] - duplicate arg name :file",
                   fn ->
                     spec(%{cmds: [subcmd: %{args: [file: %{}, file: %{num_args: {0, 1}}]}]})
                   end
    end

    test "opt without short/long in nested cmd is rejected" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example, :subcmd] - expected :short or :long to be set",
                   fn -> spec(%{cmds: [subcmd: %{opts: [mode: %{}]}]}) end
    end

    test "flag action conflict in nested cmd is rejected" do
      assert_raise ArgumentError,
                   "opt :verbose under the cmd path [:example, :sub] - :value_parser conflicts with action: :count",
                   fn ->
                     spec(%{cmds: [sub: %{opts: [verbose: %{short: "v", action: :count, value_parser: :integer}]}]})
                   end
    end
  end

  describe "positive cases -" do
    test "spec with all kinds of children is accepted" do
      assert {_, _} =
               spec(%{
                 args: [src: %{num_args: {1, :infinity}}],
                 opts: [verbose: %{short: "v", action: :count}, output: %{long: "output", value_parser: :string}],
                 cmds: [setup: %{}, teardown: %{}]
               })
    end
  end
end
