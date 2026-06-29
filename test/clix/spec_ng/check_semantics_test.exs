defmodule CLIX.SpecNG.CheckSemanticsTest do
  use ExUnit.Case, async: true

  alias CLIX.SpecNG

  defp spec(overrides) when is_map(overrides) do
    SpecNG.new!({:example, overrides})
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

  describe "structural constraints - unbounded args -" do
    test "single unbounded arg is OK" do
      assert {_, _} = spec(%{args: [a: %{num_args: {1, :infinity}}]})
    end

    test "one unbounded arg at the end is OK" do
      assert {_, _} = spec(%{args: [a: %{num_args: 1}, b: %{num_args: {1, :infinity}}]})
    end

    test "bounded args don't trigger unbounded checks" do
      assert {_, _} = spec(%{args: [a: %{num_args: {0, 2}}, b: %{num_args: {0, 3}}]})
    end

    test "at most one unbounded arg" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - unbounded args :a and :b - at most one is allowed",
                   fn ->
                     spec(%{args: [a: %{num_args: {1, :infinity}}, b: %{num_args: {1, :infinity}}]})
                   end
    end

    test "unbounded arg not at the end is rejected" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - unbounded arg :a must be the last arg",
                   fn ->
                     spec(%{args: [a: %{num_args: {1, :infinity}}, b: %{num_args: 1}]})
                   end
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
    end
  end

  describe "field conflicts - arg -" do
    test "default_value + required: true conflicts" do
      assert_raise ArgumentError,
                   "arg :file under the cmd path [:example] - :default_value conflicts with :required: true",
                   fn -> arg(%{required: true, default_value: "x"}) end
    end

    test "default_value: nil + required: true is OK" do
      assert {_, _} = arg(%{required: true, default_value: nil})
    end

    test "default_value + required not set is OK" do
      assert {_, _} = arg(%{default_value: "x"})
    end
  end

  describe "field conflicts - opt -" do
    test "default_value + required: true conflicts" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - :default_value conflicts with :required: true",
                   fn -> opt(%{required: true, default_value: "x"}) end
    end

    test "opt without short or long is rejected" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :short or :long to be set",
                   fn -> spec(%{opts: [mode: %{}]}) end
    end

    test "flag action + num_args (non-zero) conflicts" do
      for n <- [1, 2, {1, 1}, {0, 1}, {1, :infinity}] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - flag action :count conflicts with num_args: #{inspect(n)}",
                     fn -> opt(%{action: :count, num_args: n}) end
      end
    end

    test "flag action + num_args: 0 is OK" do
      assert {_, _} = opt(%{action: :count, num_args: 0})
      assert {_, _} = opt(%{action: :count, num_args: {0, 0}})
    end

    test "flag action without num_args is OK" do
      assert {_, _} = opt(%{action: :count})
    end

    test "flag action + default_value conflicts" do
      for action <- [:set_true, :set_false, :count] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - flag action #{inspect(action)} conflicts with default_value: \"x\"",
                     fn -> opt(%{action: action, default_value: "x"}) end
      end
    end

    test "flag action + default_value: nil is OK" do
      assert {_, _} = opt(%{action: :count, default_value: nil})
    end

    test "flag action + value_parser conflicts" do
      for vp <- [:string, :integer, :float, {MyMod, :parse}] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - flag action :count conflicts with value_parser",
                     fn -> opt(%{action: :count, value_parser: vp}) end
      end
    end

    test "flag action + value_name conflicts" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - flag action :count conflicts with value_name: \"FILE\"",
                   fn -> opt(%{action: :count, value_name: "FILE"}) end
    end

    test "flag action + value_name: nil is OK" do
      assert {_, _} = opt(%{action: :count, value_name: nil})
    end

    test "value action + num_args is OK" do
      assert {_, _} = opt(%{action: :set, num_args: 2})
      assert {_, _} = opt(%{action: :append, num_args: {1, :infinity}})
    end
  end

  describe "nested cmds - semantics are validated recursively -" do
    test "duplicate arg names in nested cmd are rejected" do
      assert_raise ArgumentError,
                   "under the cmd path [:example, :sub] - duplicate arg name :file",
                   fn ->
                     spec(%{cmds: [sub: %{args: [file: %{}, file: %{num_args: {0, 1}}]}]})
                   end
    end

    test "opt without short/long in nested cmd is rejected" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example, :sub] - expected :short or :long to be set",
                   fn -> spec(%{cmds: [sub: %{opts: [mode: %{}]}]}) end
    end

    test "flag action conflict in nested cmd is rejected" do
      assert_raise ArgumentError,
                   "opt :verbose under the cmd path [:example, :sub] - flag action :count conflicts with value_parser",
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

    test "flag action with minimal fields is accepted" do
      assert {_, _} = spec(%{opts: [verbose: %{short: "v", action: :set_true}]})
      assert {_, _} = spec(%{opts: [quiet: %{long: "quiet", action: :set_false}]})
      assert {_, _} = spec(%{opts: [count: %{short: "c", action: :count}]})
    end

    test "value action with value_parser and default_value is accepted" do
      assert {_, _} =
               opt(%{
                 action: :set,
                 value_parser: :integer,
                 default_value: "0"
               })
    end
  end
end
