defmodule CLIX.SpecNGTest do
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

  describe "valid spec -" do
    test "empty cmd_spec is accepted" do
      assert {_, _} = SpecNG.new!({:my_cli, %{}})
    end

    test "nested cmds with args, opts, and sub-cmds are accepted" do
      assert {_, _} =
               SpecNG.new!(
                 {:my_cli,
                  %{
                    cmds: [
                      sub: %{
                        args: [file: %{num_args: 1}],
                        opts: [verbose: %{short: "v", action: :count}],
                        cmds: [app: %{help: "Manages the apps."}]
                      }
                    ]
                  }}
               )
    end
  end

  describe "cmd pair guards -" do
    test "cmd_name must be an atom" do
      assert_raise ArgumentError,
                   "under the cmd path [] - expected cmd_name to be an atom, got: \"my_cli\"",
                   fn -> SpecNG.new!({"my_cli", %{}}) end
    end

    test "cmd_spec must be a map" do
      assert_raise ArgumentError,
                   "under the cmd path [] - expected cmd_spec to be a map, got: \"not map\"",
                   fn -> SpecNG.new!({:example, "not map"}) end
    end

    test "non-tuple input to new! hits catch-all" do
      assert_raise ArgumentError,
                   "under the cmd path [] - expected a {cmd_name, cmd_spec} tuple, got: :atom",
                   fn -> SpecNG.new!(:atom) end
    end

    test "non-tuple element in nested cmds hits catch-all" do
      assert_raise ArgumentError,
                   "under the cmd path [:my_cli] - expected a {cmd_name, cmd_spec} tuple, got: :atom",
                   fn -> SpecNG.new!({:my_cli, %{cmds: [:atom]}}) end
    end
  end

  describe "cmd_spec fields -" do
    test "all cmd_spec fields are accepted" do
      assert {_, _} =
               spec(%{
                 help: "...",
                 args: [],
                 opts: [],
                 cmds: []
               })
    end

    test ":help must be a string or nil" do
      for h <- ["...", nil] do
        assert {_, _} = spec(%{help: h})
      end

      assert_raise ArgumentError,
                   "under the cmd path [:example] - expected :help to be a string or nil, got: 42",
                   fn -> spec(%{help: 42}) end
    end

    test ":args must be a list" do
      assert {_, _} = spec(%{args: []})

      assert_raise ArgumentError,
                   "under the cmd path [:example] - expected :args to be a list, got: %{}",
                   fn -> spec(%{args: %{}}) end
    end

    test ":opts must be a list" do
      assert {_, _} = spec(%{opts: []})

      assert_raise ArgumentError,
                   "under the cmd path [:example] - expected :opts to be a list, got: %{}",
                   fn -> spec(%{opts: %{}}) end
    end

    test ":cmds must be a list" do
      assert {_, _} = spec(%{cmds: []})

      assert_raise ArgumentError,
                   "under the cmd path [:example] - expected :cmds to be a list, got: %{}",
                   fn -> spec(%{cmds: %{}}) end
    end

    test "unknown field raises" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - unknown field :foo with value :bar",
                   fn -> spec(%{foo: :bar}) end
    end
  end

  describe "arg pair guards -" do
    test "empty arg_spec is accepted" do
      assert {_, _} = spec(%{args: [{:file, %{}}]})
    end

    test "arg_name must be an atom" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - expected arg_name to be an atom, got: \"file\"",
                   fn -> spec(%{args: [{"file", %{}}]}) end
    end

    test "arg_spec must be a map" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - expected arg_spec for :file to be a map, got: \"not map\"",
                   fn -> spec(%{args: [file: "not map"]}) end
    end

    test "non-tuple arg element hits catch-all" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - expected a {arg_name, arg_spec} tuple, got: :atom",
                   fn -> spec(%{args: [:atom]}) end
    end
  end

  describe "arg_spec fields -" do
    test "all arg_spec fields are accepted" do
      assert {_, _} =
               arg(%{
                 help: "...",
                 action: :set,
                 num_args: {1, 1},
                 value_name: "FILE",
                 value_parser: {String, []},
                 required: true,
                 default_value: nil
               })
    end

    test ":help must be a string or nil" do
      for h <- ["...", nil] do
        assert {_, _} = arg(%{help: h})
      end

      assert_raise ArgumentError,
                   "arg :file under the cmd path [:example] - expected :help to be a string or nil, got: 42",
                   fn -> arg(%{help: 42}) end
    end

    test ":action must be one of [:set, :append]" do
      for a <- [:set, :append] do
        assert {_, _} = arg(%{action: a})
      end

      for a <- [:set_true, :set_false, :count, :unknown] do
        assert_raise ArgumentError,
                     "arg :file under the cmd path [:example] - expected :action to be one of [:set, :append], got: #{inspect(a)}",
                     fn -> arg(%{action: a}) end
      end
    end

    # The :num_args field gets its own separate describe block.

    test ":value_name must be a string or nil" do
      for vn <- ["...", nil] do
        assert {_, _} = arg(%{value_name: vn})
      end

      assert_raise ArgumentError,
                   "arg :file under the cmd path [:example] - expected :value_name to be a string or nil, got: 42",
                   fn -> arg(%{value_name: 42}) end
    end

    test ":value_parser must be a {module(), args :: list()} tuple" do
      assert {_, _} = arg(%{value_parser: {String, []}})

      for vp <- [{MyMod}, {"mod", []}, :bad, {MyMod, "not list"}, {1, []}] do
        assert_raise ArgumentError,
                     "arg :file under the cmd path [:example] - expected :value_parser to be a {module(), args :: list()} tuple, got: #{inspect(vp)}",
                     fn -> arg(%{value_parser: vp}) end
      end
    end

    test ":required must be a boolean" do
      for r <- [true, false] do
        assert {_, _} = arg(%{required: r})
      end

      for r <- [0, 1, nil, "true"] do
        assert_raise ArgumentError,
                     "arg :file under the cmd path [:example] - expected :required to be a boolean, got: #{inspect(r)}",
                     fn -> arg(%{required: r}) end
      end
    end

    test ":default_value must be a string or nil" do
      for dv <- ["...", nil] do
        assert {_, _} = arg(%{default_value: dv})
      end

      for dv <- [42, :atom, [1, 2], %{}] do
        assert_raise ArgumentError,
                     "arg :file under the cmd path [:example] - expected :default_value to be a string or nil, got: #{inspect(dv)}",
                     fn -> arg(%{default_value: dv}) end
      end
    end

    test "unknown field raises" do
      assert_raise ArgumentError,
                   "arg :file under the cmd path [:example] - unknown field :foo with value 1",
                   fn -> arg(%{foo: 1}) end
    end
  end

  describe "arg :num_args -" do
    test "integer, exact tuple, range tuple, and :infinity are valid" do
      for na <- [1, 2, 5] do
        assert {_, _} = arg(%{num_args: na})
      end

      for na <- [{1, 1}, {2, 2}, {5, 5}] do
        assert {_, _} = arg(%{num_args: na})
      end

      for na <- [{0, 1}, {0, 5}, {2, 4}] do
        assert {_, _} = arg(%{num_args: na})
      end

      for na <- [{0, :infinity}, {1, :infinity}, {5, :infinity}] do
        assert {_, _} = arg(%{num_args: na})
      end
    end

    test "tuple {-1, 2} is invalid (min < 0)" do
      assert_raise ArgumentError,
                    "arg :file under the cmd path [:example] - expected :num_args to be a positive integer or a {min, max} tuple " <>
                      "(min >= 0, max >= 1 or :infinity, min <= max), got: {-1, 2}",
                   fn -> arg(%{num_args: {-1, 2}}) end
    end

    test "integer 0 is invalid (arg requires max >= 1)" do
      assert_raise ArgumentError,
                    "arg :file under the cmd path [:example] - expected :num_args to be a positive integer or a {min, max} tuple " <>
                      "(min >= 0, max >= 1 or :infinity, min <= max), got: 0",
                   fn -> arg(%{num_args: 0}) end
    end

    test "tuple {0, 0} is invalid (arg requires max >= 1)" do
      assert_raise ArgumentError,
                    "arg :file under the cmd path [:example] - expected :num_args to be a positive integer or a {min, max} tuple " <>
                      "(min >= 0, max >= 1 or :infinity, min <= max), got: {0, 0}",
                   fn -> arg(%{num_args: {0, 0}}) end
    end

    test "tuple {3, 1} is invalid (min > max)" do
      assert_raise ArgumentError,
                    "arg :file under the cmd path [:example] - expected :num_args to be a positive integer or a {min, max} tuple " <>
                      "(min >= 0, max >= 1 or :infinity, min <= max), got: {3, 1}",
                   fn -> arg(%{num_args: {3, 1}}) end
    end

    test ":infinity alone is invalid" do
      assert_raise ArgumentError,
                    "arg :file under the cmd path [:example] - expected :num_args to be a positive integer or a {min, max} tuple " <>
                      "(min >= 0, max >= 1 or :infinity, min <= max), got: :infinity",
                   fn -> arg(%{num_args: :infinity}) end
    end

    test "other shapes of data are invalid" do
      for na <- ["oops", 1.0, {1}, {1, 2, 3}] do
        assert_raise ArgumentError,
                      "arg :file under the cmd path [:example] - expected :num_args to be a positive integer or a {min, max} tuple " <>
                        "(min >= 0, max >= 1 or :infinity, min <= max), got: #{inspect(na)}",
                     fn -> arg(%{num_args: na}) end
      end
    end
  end

  describe "opt pair guards -" do
    test "empty opt_spec is accepted" do
      assert {_, _} = spec(%{opts: [mode: %{}]})
    end

    test "opt_name must be an atom" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - expected opt_name to be an atom, got: \"mode\"",
                   fn -> spec(%{opts: [{"mode", %{}}]}) end
    end

    test "opt_spec must be a map" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - expected opt_spec for :mode to be a map, got: \"not map\"",
                   fn -> spec(%{opts: [mode: "not map"]}) end
    end

    test "non-tuple opt element hits catch-all" do
      assert_raise ArgumentError,
                   "under the cmd path [:example] - expected a {opt_name, opt_spec} tuple, got: :atom",
                   fn -> spec(%{opts: [:atom]}) end
    end
  end

  describe "opt_spec fields -" do
    test "all opt_spec fields are accepted" do
      assert {_, _} =
               opt(%{
                 help: "verbose level",
                 short: "v",
                 long: "verbose",
                 action: :count,
                 num_args: 0,
                 value_name: "VERBOSE",
                 value_parser: {Integer, []},
                 required: false,
                 default_value: nil
               })
    end

    test ":help must be a string or nil" do
      for h <- ["...", nil] do
        assert {_, _} = arg(%{help: h})
      end

      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :help to be a string or nil, got: 42",
                   fn -> opt(%{help: 42}) end
    end

    # The :short field gets its own separate describe block.

    # The :long field gets its own separate describe block.

    test ":action must be one of [:set, :append, :set_true, :set_false, :count]" do
      for a <- [:set, :append, :set_true, :set_false, :count] do
        assert {_, _} = opt(%{action: a})
      end

      for a <- [:unknown] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - expected :action to be one of [:set, :append, :set_true, :set_false, :count], got: #{inspect(a)}",
                     fn -> opt(%{action: a}) end
      end
    end

    # The :num_args field gets its own separate describe block.

    test ":value_name must be a string or nil" do
      for vn <- ["...", nil] do
        assert {_, _} = opt(%{value_name: vn})
      end

      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :value_name to be a string or nil, got: 42",
                   fn -> opt(%{value_name: 42}) end
    end

    test ":value_parser must be a {module(), args :: list()} tuple" do
      assert {_, _} = opt(%{value_parser: {String, []}})

      for bad <- [{MyMod}, {"mod", []}, :bad, {MyMod, "not list"}, {1, []}] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - expected :value_parser to be a {module(), args :: list()} tuple, got: #{inspect(bad)}",
                     fn -> opt(%{value_parser: bad}) end
      end
    end

    test ":required must be a boolean" do
      for r <- [true, false] do
        assert {_, _} = opt(%{required: r})
      end

      for r <- [0, 1, nil, "true"] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - expected :required to be a boolean, got: #{inspect(r)}",
                     fn -> opt(%{required: r}) end
      end
    end

    test ":default_value must be a string or nil" do
      for dv <- ["...", nil] do
        assert {_, _} = opt(%{default_value: dv})
      end

      for dv <- [42, :atom, [1, 2], %{}] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - expected :default_value to be a string or nil, got: #{inspect(dv)}",
                     fn -> opt(%{default_value: dv}) end
      end
    end

    test "unknown field raises" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - unknown field :foo with value 1",
                   fn -> opt(%{foo: 1}) end
    end
  end

  describe "opt :short -" do
    test "single letter is valid" do
      assert {_, _} = opt(%{short: "m"})
    end

    test "multi-character string is invalid" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :short to be a single-character string or nil, got: \"mod\"",
                   fn -> opt(%{short: "mod"}) end
    end

    test "digit, '-', '=', whitespace are invalid" do
      for s <- ["0", "9", "-", "=", " ", "\t", "\n"] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - expected :short to not be a digit, '-', '=', or whitespace, got: #{inspect(s)}",
                     fn -> opt(%{short: s}) end
      end
    end

    test "non-binary is invalid" do
      for s <- [?a, :a] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - expected :short to be a single-character string or nil, got: #{inspect(s)}",
                     fn -> opt(%{short: s}) end
      end
    end
  end

  describe "opt :long -" do
    test "multi-char, underscored, and hyphenated strings are valid" do
      assert {_, _} = opt(%{long: "mode"})
      assert {_, _} = opt(%{long: "edit_mode"})
      assert {_, _} = opt(%{long: "edit-mode"})
    end

    test "empty string is invalid (length < 2)" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :long to be a string of length >= 2 or nil, got: \"\"",
                   fn -> opt(%{long: ""}) end
    end

    test "single-character is invalid (length < 2)" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :long to be a string of length >= 2 or nil, got: \"m\"",
                   fn -> opt(%{long: "m"}) end
    end

    test "starting with '-' is invalid" do
      for l <- ["-foo", "--foo", "-v"] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - expected :long to not start with '-', got: #{inspect(l)}",
                     fn -> opt(%{long: l}) end
      end
    end

    test "containing '=' is invalid" do
      for l <- ["foo=", "foo=bar", "=bar"] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - expected :long to not contain '=', got: #{inspect(l)}",
                     fn -> opt(%{long: l}) end
      end
    end

    test "containing whitespace is invalid" do
      for l <- ["foo bar", "foo\tbar", "foo\nbar"] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - expected :long to not contain whitespace, got: #{inspect(l)}",
                     fn -> opt(%{long: l}) end
      end
    end

    test "non-binary is invalid" do
      for l <- [42, :mode] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - expected :long to be a string of length >= 2 or nil, got: #{inspect(l)}",
                     fn -> opt(%{long: l}) end
      end
    end
  end

  describe "opt :num_args -" do
    test "integer, exact tuple, range tuple, and :infinity are valid" do
      for na <- [0, 1, 2, 5] do
        assert {_, _} = opt(%{num_args: na})
      end

      for na <- [{0, 0}, {1, 1}, {2, 2}, {5, 5}] do
        assert {_, _} = opt(%{num_args: na})
      end

      for na <- [{0, 1}, {0, 5}, {2, 4}] do
        assert {_, _} = opt(%{num_args: na})
      end

      for na <- [{0, :infinity}, {1, :infinity}, {5, :infinity}] do
        assert {_, _} = opt(%{num_args: na})
      end
    end

    test "tuple {-1, 2} is invalid (min < 0)" do
      assert_raise ArgumentError,
                    "opt :mode under the cmd path [:example] - expected :num_args to be a non-negative integer or a {min, max} tuple " <>
                      "(min >= 0, max >= 0 or :infinity, min <= max), got: {-1, 2}",
                   fn -> opt(%{num_args: {-1, 2}}) end
    end

    test "tuple {3, 1} is invalid (min > max)" do
      assert_raise ArgumentError,
                    "opt :mode under the cmd path [:example] - expected :num_args to be a non-negative integer or a {min, max} tuple " <>
                      "(min >= 0, max >= 0 or :infinity, min <= max), got: {3, 1}",
                   fn -> opt(%{num_args: {3, 1}}) end
    end

    test ":infinity alone is invalid" do
      assert_raise ArgumentError,
                    "opt :mode under the cmd path [:example] - expected :num_args to be a non-negative integer or a {min, max} tuple " <>
                      "(min >= 0, max >= 0 or :infinity, min <= max), got: :infinity",
                   fn -> opt(%{num_args: :infinity}) end
    end

    test "other shapes of data are invalid" do
      for na <- ["oops", 1.0, {1}, {1, 2, 3}] do
        assert_raise ArgumentError,
                      "opt :mode under the cmd path [:example] - expected :num_args to be a non-negative integer or a {min, max} tuple " <>
                        "(min >= 0, max >= 0 or :infinity, min <= max), got: #{inspect(na)}",
                     fn -> opt(%{num_args: na}) end
      end
    end
  end

  describe "nested cmds -" do
    test "nested cmds are validated" do
      assert_raise ArgumentError,
                   "under the cmd path [:example, :cmd1] - expected :help to be a string or nil, got: 42",
                   fn -> spec(%{cmds: [cmd1: %{help: 42}]}) end
    end

    test "deeply nested cmds are validated" do
      assert_raise ArgumentError,
                   "arg :file under the cmd path [:example, :cmd1, :cmd2] - expected :help to be a string or nil, got: 42",
                   fn ->
                     spec(%{cmds: [cmd1: %{cmds: [cmd2: %{args: [file: %{help: 42}]}]}]})
                   end
    end

    test "nested cmds' args are validated" do
      assert_raise ArgumentError,
                   "arg :file under the cmd path [:example, :cmd1] - expected :help to be a string or nil, got: 42",
                   fn -> spec(%{cmds: [cmd1: %{args: [file: %{help: 42}]}]}) end
    end

    test "nested cmds' opts are validated" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example, :cmd1] - expected :help to be a string or nil, got: 42",
                   fn -> spec(%{cmds: [cmd1: %{opts: [mode: %{help: 42}]}]}) end
    end
  end
end
