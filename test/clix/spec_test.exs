defmodule CLIX.SpecTest do
  use ExUnit.Case, async: true

  alias CLIX.Spec

  describe "cmds -" do
    test "no duplicate cmd names" do
      assert_raise ArgumentError,
                   "duplicate cmd name :setup under the cmd path [:example]",
                   fn ->
                     Spec.new({:example, %{cmds: [setup: %{}, setup: %{}]}})
                   end
    end

    test ":help / :summary / :description / :epilogue must be a string or nil" do
      for field <- [:help, :summary, :description, :epilogue] do
        assert_raise ArgumentError,
                     "under the cmd path [:example] - expected #{inspect(field)} to be a string or nil, got: 42",
                     fn ->
                       Spec.new({:example, Map.put(%{}, field, 42)})
                     end
      end

      # nil and string are both fine
      assert {_, _} = Spec.new({:example, %{summary: nil, description: "ok", help: "h", epilogue: "e"}})
    end

    test "cmd-level string check fires on nested cmds too" do
      assert_raise ArgumentError,
                   "under the cmd path [:example, :sub] - expected :description to be a string or nil, got: 99",
                   fn ->
                     Spec.new({:example, %{cmds: [sub: %{description: 99}]}})
                   end
    end

    test "sub-cmd name must be an atom and sub-cmd spec must be a map" do
      assert_raise FunctionClauseError, fn ->
        Spec.new({:example, %{cmds: [{"not_atom", %{}}]}})
      end

      assert_raise FunctionClauseError, fn ->
        Spec.new({:example, %{cmds: [sub: "not_a_map"]}})
      end
    end
  end

  describe "args -" do
    test "no duplicate arg names" do
      assert_raise ArgumentError,
                   "duplicate arg name :file under the cmd path [:example]",
                   fn ->
                     Spec.new({:example, %{args: [file: %{}, file: %{nargs: :*}]}})
                   end
    end

    test "at most one unbounded arg" do
      assert_raise ArgumentError,
                   "unbounded args :a (:nargs :*) and :b (:nargs :*) under the cmd path [:example] - at most one is allowed",
                   fn ->
                     Spec.new({:example, %{args: [a: %{nargs: :*}, b: %{nargs: :*}]}})
                   end

      assert_raise ArgumentError,
                   "unbounded args :a (:nargs :+) and :b (:nargs :+) under the cmd path [:example] - at most one is allowed",
                   fn ->
                     Spec.new({:example, %{args: [a: %{nargs: :+}, b: %{nargs: :+}]}})
                   end

      assert_raise ArgumentError,
                   "unbounded args :a (:nargs :+) and :b (:nargs :*) under the cmd path [:example] - at most one is allowed",
                   fn ->
                     Spec.new({:example, %{args: [a: %{nargs: :+}, b: %{nargs: :*}]}})
                   end

      # cp-style: one :+ + one :!
      assert {_, _} = Spec.new({:example, %{args: [src: %{nargs: :+}, dst: %{}]}})

      # httpie-style: :? + :! + :*
      assert {_, _} =
               Spec.new({:example, %{args: [method: %{nargs: :"?"}, url: %{}, items: %{nargs: :*}]}})

      # multiple :? are bounded - fine
      assert {_, _} = Spec.new({:example, %{args: [a: %{nargs: :"?"}, b: %{nargs: :"?"}]}})
    end

    test ":type must be a known atom, {:custom, fun}, or {:custom, {mod, fun}}" do
      assert_raise ArgumentError,
                   "arg :file under the cmd path [:example] - expected :type to be one of " <>
                     "[:string, :boolean, :integer, :float, {:custom, fun}, " <>
                     "{:custom, {mod, fun}}], got: :unknown",
                   fn ->
                     Spec.new({:example, %{args: [file: %{type: :unknown}]}})
                   end

      # :custom with non-function value
      assert_raise ArgumentError,
                   ~r/expected :type to be one of/,
                   fn ->
                     Spec.new({:example, %{args: [file: %{type: {:custom, "not a fun"}}]}})
                   end

      # :custom with wrong arity
      assert_raise ArgumentError,
                   ~r/expected :type to be one of/,
                   fn ->
                     Spec.new({:example, %{args: [file: %{type: {:custom, fn -> :ok end}}]}})
                   end

      # :custom with bad MFA shape (non-atom function name)
      assert_raise ArgumentError,
                   ~r/expected :type to be one of/,
                   fn ->
                     Spec.new({:example, %{args: [file: %{type: {:custom, {Date, "from_iso8601"}}}]}})
                   end

      # good :custom with anonymous function
      assert {_, _} =
               Spec.new({:example, %{args: [file: %{type: {:custom, fn _ -> {:ok, 1} end}}]}})

      # good :custom with named function (Macro.escape-friendly)
      assert {_, _} =
               Spec.new({:example, %{args: [file: %{type: {:custom, {Date, :from_iso8601}}}]}})
    end

    test ":nargs must be a known atom" do
      assert_raise ArgumentError,
                   "arg :file under the cmd path [:example] - expected :nargs to be one of " <>
                     "[:!, :\"?\", :+, :*], got: :unknown",
                   fn ->
                     Spec.new({:example, %{args: [file: %{nargs: :unknown}]}})
                   end
    end

    test ":nargs :! and :+ cannot coexist with :default" do
      # nargs: :! - explicit
      assert_raise ArgumentError,
                   "arg :file under the cmd path [:example] - expected :default not to be set when :nargs is :!",
                   fn ->
                     Spec.new({:example, %{args: [file: %{nargs: :!, default: "x"}]}})
                   end

      # nargs: :! - implicit (default-fill of nargs)
      assert_raise ArgumentError,
                   "arg :file under the cmd path [:example] - expected :default not to be set when :nargs is :!",
                   fn ->
                     Spec.new({:example, %{args: [file: %{default: "x"}]}})
                   end

      # nargs: :+
      assert_raise ArgumentError,
                   "arg :file under the cmd path [:example] - expected :default not to be set when :nargs is :+",
                   fn ->
                     Spec.new({:example, %{args: [file: %{nargs: :+, default: ["x"]}]}})
                   end

      # allowed combos
      assert {_, _} = Spec.new({:example, %{args: [file: %{nargs: :"?", default: "x"}]}})
      assert {_, _} = Spec.new({:example, %{args: [file: %{nargs: :*, default: ["x"]}]}})

      # required nargs without :default - fine
      assert {_, _} = Spec.new({:example, %{args: [file: %{nargs: :!}]}})
      assert {_, _} = Spec.new({:example, %{args: [file: %{nargs: :+}]}})
    end

    test ":help must be a string or nil" do
      assert_raise ArgumentError,
                   "arg :file under the cmd path [:example] - expected :help to be a string or nil, got: 7",
                   fn ->
                     Spec.new({:example, %{args: [file: %{help: 7}]}})
                   end

      assert {_, _} = Spec.new({:example, %{args: [file: %{help: "the file"}]}})
      assert {_, _} = Spec.new({:example, %{args: [file: %{help: nil}]}})
    end

    test ":value_name must be a string or nil" do
      assert_raise ArgumentError,
                   "arg :file under the cmd path [:example] - expected :value_name to be a string or nil, got: 42",
                   fn ->
                     Spec.new({:example, %{args: [file: %{value_name: 42}]}})
                   end

      assert {_, _} = Spec.new({:example, %{args: [file: %{value_name: "FILE"}]}})
      assert {_, _} = Spec.new({:example, %{args: [file: %{value_name: nil}]}})
    end

    test ":default must match :type" do
      # nargs :? — single value mismatch
      assert_raise ArgumentError,
                   "arg :n under the cmd path [:example] - expected :default to match :type :integer, got: \"x\"",
                   fn ->
                     Spec.new({:example, %{args: [n: %{type: :integer, nargs: :"?", default: "x"}]}})
                   end

      # nargs :* — list shape required
      assert_raise ArgumentError,
                   "arg :items under the cmd path [:example] - expected :default to be a list of :type :string, got: \"x\"",
                   fn ->
                     Spec.new({:example, %{args: [items: %{nargs: :*, default: "x"}]}})
                   end

      # nargs :* — list element mismatch
      assert_raise ArgumentError,
                   "arg :items under the cmd path [:example] - expected :default to be a list of :type :integer, got: [1, \"two\"]",
                   fn ->
                     Spec.new({:example, %{args: [items: %{type: :integer, nargs: :*, default: [1, "two"]}]}})
                   end

      # nil is always allowed
      assert {_, _} = Spec.new({:example, %{args: [n: %{type: :integer, nargs: :"?", default: nil}]}})

      # matching combos
      assert {_, _} = Spec.new({:example, %{args: [n: %{type: :integer, nargs: :"?", default: 0}]}})
      assert {_, _} = Spec.new({:example, %{args: [items: %{type: :integer, nargs: :*, default: [1, 2]}]}})

      # :custom is opaque - any default allowed
      assert {_, _} =
               Spec.new({:example, %{args: [x: %{type: {:custom, fn s -> {:ok, s} end}, nargs: :"?", default: :anything}]}})
    end
  end

  describe "opts -" do
    test "requirement of short and long" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :short or :long to be set",
                   fn ->
                     Spec.new({:example, %{opts: [mode: %{}]}})
                   end
    end

    test "the length of short" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :short to be an one-char string, got: \"mod\"",
                   fn ->
                     Spec.new({:example, %{opts: [mode: %{short: "mod"}]}})
                   end

      assert {_, _} = Spec.new({:example, %{opts: [mode: %{short: "m"}]}})
    end

    test "the length of long" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :long to be a multi-chars string, got: \"m\"",
                   fn ->
                     Spec.new({:example, %{opts: [mode: %{long: "m"}]}})
                   end

      assert {_, _} = Spec.new({:example, %{opts: [mode: %{long: "mode"}]}})
    end

    test ":short cannot be a digit, '-', '=', or whitespace" do
      for s <- ["-", "=", " ", "\t", "0", "5", "9"] do
        assert_raise ArgumentError,
                     "opt :mode under the cmd path [:example] - expected :short to not be a digit, \"-\", \"=\", or whitespace, got: #{inspect(s)}",
                     fn ->
                       Spec.new({:example, %{opts: [mode: %{short: s}]}})
                     end
      end
    end

    test ":long cannot start with '-'" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :long to not start with '-', got: \"-foo\"",
                   fn ->
                     Spec.new({:example, %{opts: [mode: %{long: "-foo"}]}})
                   end

      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :long to not start with '-', got: \"--foo\"",
                   fn ->
                     Spec.new({:example, %{opts: [mode: %{long: "--foo"}]}})
                   end

      # internal hyphen is fine
      assert {_, _} = Spec.new({:example, %{opts: [mode: %{long: "foo-bar"}]}})
    end

    test ":long cannot contain '='" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :long to not contain '=', got: \"foo=bar\"",
                   fn ->
                     Spec.new({:example, %{opts: [mode: %{long: "foo=bar"}]}})
                   end
    end

    test ":type must be a known atom or {:custom, fun_of_arity_1}" do
      assert_raise ArgumentError,
                   ~r/expected :type to be one of/,
                   fn ->
                     Spec.new({:example, %{opts: [mode: %{long: "mode", type: :unknown}]}})
                   end
    end

    test ":action must be one of :set, :count, :append" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :action to be one of " <>
                     "[:set, :count, :append], got: :unknown",
                   fn ->
                     Spec.new({:example, %{opts: [mode: %{long: "mode", action: :unknown}]}})
                   end
    end

    test ":count action requires :boolean type" do
      assert_raise ArgumentError,
                   "opt :verbose under the cmd path [:example] - expected :type to be :boolean when :action is :count, got: :string",
                   fn ->
                     Spec.new({:example, %{opts: [verbose: %{short: "v", action: :count}]}})
                   end

      assert_raise ArgumentError,
                   "opt :verbose under the cmd path [:example] - expected :type to be :boolean when :action is :count, got: :integer",
                   fn ->
                     Spec.new({:example, %{opts: [verbose: %{short: "v", type: :integer, action: :count}]}})
                   end

      assert {_, _} = Spec.new({:example, %{opts: [verbose: %{short: "v", type: :boolean, action: :count}]}})
    end

    test ":required cannot coexist with :default" do
      assert_raise ArgumentError,
                   "opt :name under the cmd path [:example] - expected :default not to be set when :required is true",
                   fn ->
                     Spec.new({:example, %{opts: [name: %{long: "name", required: true, default: "x"}]}})
                   end

      assert {_, _} = Spec.new({:example, %{opts: [name: %{long: "name", required: true}]}})
      assert {_, _} = Spec.new({:example, %{opts: [name: %{long: "name", default: "x"}]}})
    end

    test ":help must be a string or nil" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :help to be a string or nil, got: 7",
                   fn ->
                     Spec.new({:example, %{opts: [mode: %{long: "mode", help: 7}]}})
                   end

      assert {_, _} = Spec.new({:example, %{opts: [mode: %{long: "mode", help: "the mode"}]}})
      assert {_, _} = Spec.new({:example, %{opts: [mode: %{long: "mode", help: nil}]}})
    end

    test ":value_name must be a string or nil" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :value_name to be a string or nil, got: 42",
                   fn ->
                     Spec.new({:example, %{opts: [mode: %{long: "mode", value_name: 42}]}})
                   end

      assert {_, _} = Spec.new({:example, %{opts: [mode: %{long: "mode", value_name: "MODE"}]}})
      assert {_, _} = Spec.new({:example, %{opts: [mode: %{long: "mode", value_name: nil}]}})
    end

    test ":required must be a boolean" do
      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :required to be a boolean, got: \"yes\"",
                   fn ->
                     Spec.new({:example, %{opts: [mode: %{long: "mode", required: "yes"}]}})
                   end

      assert_raise ArgumentError,
                   "opt :mode under the cmd path [:example] - expected :required to be a boolean, got: nil",
                   fn ->
                     Spec.new({:example, %{opts: [mode: %{long: "mode", required: nil}]}})
                   end

      assert {_, _} = Spec.new({:example, %{opts: [mode: %{long: "mode", required: true}]}})
      assert {_, _} = Spec.new({:example, %{opts: [mode: %{long: "mode", required: false}]}})
    end

    test ":default must match :type" do
      # action :set — single value mismatch
      assert_raise ArgumentError,
                   "opt :n under the cmd path [:example] - expected :default to match :type :integer, got: \"x\"",
                   fn ->
                     Spec.new({:example, %{opts: [n: %{short: "n", type: :integer, default: "x"}]}})
                   end

      # action :count — must be integer (type is :boolean by the :count rule)
      assert_raise ArgumentError,
                   "opt :v under the cmd path [:example] - expected :default to be an integer when :action is :count, got: \"x\"",
                   fn ->
                     Spec.new({:example, %{opts: [v: %{short: "v", type: :boolean, action: :count, default: "x"}]}})
                   end

      # action :append — must be a list of type
      assert_raise ArgumentError,
                   "opt :t under the cmd path [:example] - expected :default to be a list of :type :string, got: \"x\"",
                   fn ->
                     Spec.new({:example, %{opts: [t: %{short: "t", action: :append, default: "x"}]}})
                   end

      assert_raise ArgumentError,
                   "opt :t under the cmd path [:example] - expected :default to be a list of :type :integer, got: [1, \"two\"]",
                   fn ->
                     Spec.new({:example, %{opts: [t: %{short: "t", type: :integer, action: :append, default: [1, "two"]}]}})
                   end

      # matching combos
      assert {_, _} = Spec.new({:example, %{opts: [n: %{short: "n", type: :integer, default: 7}]}})
      assert {_, _} = Spec.new({:example, %{opts: [v: %{short: "v", type: :boolean, action: :count, default: 3}]}})
      assert {_, _} = Spec.new({:example, %{opts: [t: %{short: "t", action: :append, default: ["a", "b"]}]}})

      # nil is always allowed
      assert {_, _} = Spec.new({:example, %{opts: [n: %{short: "n", type: :integer, default: nil}]}})
    end

    test "no duplicate opt names" do
      assert_raise ArgumentError,
                   "duplicate opt name :name under the cmd path [:example]",
                   fn ->
                     Spec.new({:example, %{opts: [name: %{long: "a"}, name: %{long: "b"}]}})
                   end
    end

    test "no duplicate :short across opts" do
      assert_raise ArgumentError,
                   "duplicate opt :short \"v\" between :verbose and :version under the cmd path [:example]",
                   fn ->
                     Spec.new({:example, %{opts: [verbose: %{short: "v"}, version: %{short: "v"}]}})
                   end
    end

    test "no duplicate :long across opts" do
      assert_raise ArgumentError,
                   "duplicate opt :long \"name\" between :a and :b under the cmd path [:example]",
                   fn ->
                     Spec.new({:example, %{opts: [a: %{long: "name"}, b: %{long: "name"}]}})
                   end
    end

    test "nil :short and nil :long are not treated as duplicates" do
      assert {_, _} =
               Spec.new({:example, %{opts: [a: %{long: "alpha"}, b: %{long: "beta"}]}})

      assert {_, _} =
               Spec.new({:example, %{opts: [a: %{short: "a"}, b: %{short: "b"}]}})
    end
  end
end
