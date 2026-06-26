defmodule CLIX.ParserTest do
  use ExUnit.Case, async: true

  alias CLIX.Spec
  alias CLIX.Parser

  doctest Parser

  # Public helper so the MFA form {:custom, {__MODULE__, :parse_date}} can resolve it.
  def parse_date(string) do
    case Date.from_iso8601(string) do
      {:ok, _} = ok -> ok
      {:error, _} -> {:error, "invalid date"}
    end
  end

  describe "args - :type attr" do
    test "default to :string" do
      spec = new_spec(%{args: [arg: %{}]})
      assert Parser.parse(spec, ["a"]) == {[], %{arg: "a"}, %{}, []}
    end

    test ":string" do
      spec = new_spec(%{args: [arg: %{type: :string}]})
      assert Parser.parse(spec, ["a"]) == {[], %{arg: "a"}, %{}, []}
    end

    test ":boolean" do
      spec = new_spec(%{args: [arg: %{type: :boolean}]})
      assert Parser.parse(spec, ["true"]) == {[], %{arg: true}, %{}, []}
      assert Parser.parse(spec, ["false"]) == {[], %{arg: false}, %{}, []}

      assert Parser.parse(spec, ["other"]) ==
               {[], %{}, %{},
                [
                  {:invalid_arg, %{message: nil, type: :boolean, value: "other", nargs: :!, value_name: "ARG"}},
                  {:missing_arg, %{message: nil, type: :boolean, value: nil, nargs: :!, value_name: "ARG"}}
                ]}
    end

    test ":integer" do
      spec = new_spec(%{args: [arg: %{type: :integer}]})
      assert Parser.parse(spec, ["0"]) == {[], %{arg: 0}, %{}, []}
      assert Parser.parse(spec, ["1"]) == {[], %{arg: 1}, %{}, []}
      assert Parser.parse(spec, ["-1"]) == {[], %{arg: -1}, %{}, []}

      assert Parser.parse(spec, ["other"]) ==
               {[], %{}, %{},
                [
                  {:invalid_arg, %{message: nil, type: :integer, value: "other", nargs: :!, value_name: "ARG"}},
                  {:missing_arg, %{message: nil, type: :integer, value: nil, nargs: :!, value_name: "ARG"}}
                ]}
    end

    test ":float" do
      spec = new_spec(%{args: [arg: %{type: :float}]})
      assert Parser.parse(spec, ["0.0"]) == {[], %{arg: 0}, %{}, []}
      assert Parser.parse(spec, ["1.1"]) == {[], %{arg: 1.1}, %{}, []}
      assert Parser.parse(spec, ["-1.1"]) == {[], %{arg: -1.1}, %{}, []}

      assert Parser.parse(spec, ["other"]) ==
               {[], %{}, %{},
                [
                  {:invalid_arg, %{message: nil, type: :float, value: "other", nargs: :!, value_name: "ARG"}},
                  {:missing_arg, %{message: nil, type: :float, value: nil, nargs: :!, value_name: "ARG"}}
                ]}
    end

    test ":custom" do
      spec =
        new_spec(%{
          args: [
            arg: %{
              type:
                {:custom,
                 fn string ->
                   case Date.from_iso8601(string) do
                     {:ok, _} = ok_tuple -> ok_tuple
                     {:error, _} -> {:error, "invalid date"}
                   end
                 end}
            }
          ]
        })

      assert Parser.parse(spec, ["2015-01-23"]) == {[], %{arg: ~D[2015-01-23]}, %{}, []}

      assert Parser.parse(spec, ["bad_date"]) ==
               {[], %{}, %{},
                [
                  {:invalid_arg, %{message: "invalid date", type: :custom, value: "bad_date", nargs: :!, value_name: "ARG"}},
                  {:missing_arg, %{message: nil, type: :custom, value: nil, nargs: :!, value_name: "ARG"}}
                ]}
    end

    test ":custom with {mod, fun}" do
      spec = new_spec(%{args: [arg: %{type: {:custom, {__MODULE__, :parse_date}}}]})

      assert Parser.parse(spec, ["2015-01-23"]) == {[], %{arg: ~D[2015-01-23]}, %{}, []}

      assert Parser.parse(spec, ["bad_date"]) ==
               {[], %{}, %{},
                [
                  {:invalid_arg, %{message: "invalid date", type: :custom, value: "bad_date", nargs: :!, value_name: "ARG"}},
                  {:missing_arg, %{message: nil, type: :custom, value: nil, nargs: :!, value_name: "ARG"}}
                ]}
    end
  end

  describe "args - :nargs attr" do
    test ":!" do
      spec = new_spec(%{args: [arg: %{nargs: :!}]})

      assert Parser.parse(spec, []) ==
               {[], %{}, %{}, [{:missing_arg, %{message: nil, type: :string, value: nil, nargs: :!, value_name: "ARG"}}]}

      assert Parser.parse(spec, ["a"]) == {[], %{arg: "a"}, %{}, []}
      assert Parser.parse(spec, ["a", "b"]) == {[], %{arg: "a"}, %{}, [{:unknown_arg, "b"}]}
    end

    test ":\"?\"" do
      spec = new_spec(%{args: [arg: %{nargs: :"?"}]})

      assert Parser.parse(spec, []) == {[], %{arg: nil}, %{}, []}
      assert Parser.parse(spec, ["a"]) == {[], %{arg: "a"}, %{}, []}
      assert Parser.parse(spec, ["a", "b"]) == {[], %{arg: "a"}, %{}, [{:unknown_arg, "b"}]}
    end

    test ":*" do
      spec = new_spec(%{args: [arg: %{nargs: :*}]})

      assert Parser.parse(spec, []) == {[], %{arg: []}, %{}, []}
      assert Parser.parse(spec, ["a"]) == {[], %{arg: ["a"]}, %{}, []}
      assert Parser.parse(spec, ["a", "b"]) == {[], %{arg: ["a", "b"]}, %{}, []}
    end

    test ":+" do
      spec = new_spec(%{args: [arg: %{nargs: :+}]})

      assert Parser.parse(spec, []) ==
               {[], %{}, %{},
                [
                  {:missing_arg, %{message: nil, type: :string, value: nil, nargs: :+, value_name: "ARG"}}
                ]}

      assert Parser.parse(spec, ["a"]) == {[], %{arg: ["a"]}, %{}, []}
      assert Parser.parse(spec, ["a", "b"]) == {[], %{arg: ["a", "b"]}, %{}, []}
    end
  end

  describe "args - :default attr" do
    test "for nargs - #{inspect(:!)}" do
      # no test for it, because it means the argument is required
    end

    test "for :nargs - #{inspect(:"?")}" do
      spec = new_spec(%{args: [arg: %{nargs: :"?", default: "a"}]})
      assert Parser.parse(spec, []) == {[], %{arg: "a"}, %{}, []}
      assert Parser.parse(spec, ["b"]) == {[], %{arg: "b"}, %{}, []}
    end

    test "for :nargs - #{inspect(:+)}" do
      # no test for it, because it means the argument is required
    end

    test "for :nargs - #{inspect(:*)}" do
      spec = new_spec(%{args: [arg: %{nargs: :*, default: ["a"]}]})
      assert Parser.parse(spec, []) == {[], %{arg: ["a"]}, %{}, []}
      assert Parser.parse(spec, ["b"]) == {[], %{arg: ["b"]}, %{}, []}
    end

  end

  describe "args - errors" do
    test "generate {:unknown_arg, arg} error where there're remaining arguments" do
      spec = new_spec(%{})
      assert Parser.parse(spec, ["a", "b"]) == {[], %{}, %{}, [{:unknown_arg, "a"}, {:unknown_arg, "b"}]}
    end

    test "generate {:missing_arg, key} error when required args are missing" do
      spec = new_spec(%{args: [arg: %{}]})

      assert Parser.parse(spec, []) ==
               {[], %{}, %{},
                [
                  {:missing_arg, %{message: nil, type: :string, value: nil, nargs: :!, value_name: "ARG"}}
                ]}
    end

    test "generate {:invalid_arg, key, arg} error" do
      spec = new_spec(%{args: [arg: %{type: :integer}]})

      assert Parser.parse(spec, ["not-integer"]) ==
               {[], %{}, %{},
                [
                  {:invalid_arg, %{message: nil, type: :integer, value: "not-integer", nargs: :!, value_name: "ARG"}},
                  {:missing_arg, %{message: nil, type: :integer, value: nil, nargs: :!, value_name: "ARG"}}
                ]}
    end
  end

  describe "opts - syntax" do
    test "--flag" do
      spec = new_spec(%{opts: [flag: %{long: "flag", type: :boolean}]})
      assert Parser.parse(spec, ["--flag"]) == {[], %{}, %{flag: true}, []}
    end

    test "--opt <value>" do
      spec = new_spec(%{opts: [opt: %{long: "opt", type: :string}]})
      assert Parser.parse(spec, ["--opt", "value"]) == {[], %{}, %{opt: "value"}, []}
    end

    test "--opt=<value>" do
      spec = new_spec(%{opts: [opt: %{long: "opt", type: :string}]})
      assert Parser.parse(spec, ["--opt=value"]) == {[], %{}, %{opt: "value"}, []}
    end

    test "-f" do
      spec = new_spec(%{opts: [flag: %{short: "f", type: :boolean}]})
      assert Parser.parse(spec, ["-f"]) == {[], %{}, %{flag: true}, []}
    end

    test "-o <value>" do
      spec = new_spec(%{opts: [opt: %{short: "o", type: :string}]})
      assert Parser.parse(spec, ["-o", "value"]) == {[], %{}, %{opt: "value"}, []}
    end

    test "-o<value>" do
      spec = new_spec(%{opts: [opt: %{short: "o", type: :string}]})
      assert Parser.parse(spec, ["-ovalue"]) == {[], %{}, %{opt: "value"}, []}
    end

    test "-abc" do
      spec =
        new_spec(%{
          opts: [
            flag_a: %{short: "a", type: :boolean},
            flag_b: %{short: "b", type: :boolean},
            flag_c: %{short: "c", type: :boolean}
          ]
        })

      assert Parser.parse(spec, ["-abc"]) == {[], %{}, %{flag_a: true, flag_b: true, flag_c: true}, []}
      assert Parser.parse(spec, ["-aXbc"]) == {[], %{}, %{flag_a: true, flag_b: false, flag_c: false}, [{:unknown_opt, "-X"}]}
    end

    test "-abco <value>" do
      spec =
        new_spec(%{
          opts: [
            flag_a: %{short: "a", type: :boolean},
            flag_b: %{short: "b", type: :boolean},
            flag_c: %{short: "c", type: :boolean},
            opt: %{short: "o", type: :string}
          ]
        })

      assert Parser.parse(spec, ["-abco", "value"]) == {[], %{}, %{flag_a: true, flag_b: true, flag_c: true, opt: "value"}, []}

      assert Parser.parse(spec, ["-aXbco", "value"]) ==
               {[], %{}, %{flag_a: true, flag_b: false, flag_c: false, opt: nil}, [{:unknown_opt, "-X"}, {:unknown_arg, "value"}]}
    end

    test "-abco<value>" do
      spec =
        new_spec(%{
          opts: [
            flag_a: %{short: "a", type: :boolean},
            flag_b: %{short: "b", type: :boolean},
            flag_c: %{short: "c", type: :boolean},
            opt: %{short: "o", type: :string}
          ]
        })

      assert Parser.parse(spec, ["-abcovalue"]) == {[], %{}, %{flag_a: true, flag_b: true, flag_c: true, opt: "value"}, []}

      assert Parser.parse(spec, ["-aXbcovalue"]) ==
               {[], %{}, %{flag_a: true, flag_b: false, flag_c: false, opt: nil}, [{:unknown_opt, "-X"}]}
    end

    test ":intermixed mode vs. :strict mode" do
      spec =
        new_spec(%{
          args: [
            arg: %{nargs: :*}
          ],
          opts: [
            flag: %{short: "f", type: :boolean},
            opt: %{short: "o", type: :string}
          ]
        })

      assert Parser.parse(spec, ["-f", "arg1", "-o", "value", "arg2"]) ==
               {[], %{arg: ["arg1", "arg2"]}, %{flag: true, opt: "value"}, []}

      assert Parser.parse(spec, ["-f", "arg1", "-o", "value", "arg2"], mode: :intermixed) ==
               {[], %{arg: ["arg1", "arg2"]}, %{flag: true, opt: "value"}, []}

      assert Parser.parse(spec, ["-f", "arg1", "-o", "value", "arg2"], mode: :strict) ==
               {[], %{arg: ["arg1", "-o", "value", "arg2"]}, %{flag: true, opt: nil}, []}
    end
  end

  describe "opts - syntax - handle '-' carefully" do
    test "there's no negative number like option" do
      spec = new_spec(%{args: [arg: %{nargs: :*}], opts: [opt: %{short: "o"}]})
      assert Parser.parse(spec, ["-o", "-1"]) == {[], %{arg: []}, %{opt: "-1"}, []}
      assert Parser.parse(spec, ["-o", "-1", "-1"]) == {[], %{arg: ["-1"]}, %{opt: "-1"}, []}
      assert Parser.parse(spec, ["-o", "-1.1"]) == {[], %{arg: []}, %{opt: "-1.1"}, []}
      assert Parser.parse(spec, ["-o", "-1.1", "-1.1"]) == {[], %{arg: ["-1.1"]}, %{opt: "-1.1"}, []}
    end

    test "negative number is treated as positional when no digit short exists" do
      spec = new_spec(%{args: [n: %{type: :integer}]})
      assert Parser.parse(spec, ["-1"]) == {[], %{n: -1}, %{}, []}
      assert Parser.parse(spec, ["-100"]) == {[], %{n: -100}, %{}, []}

      spec = new_spec(%{args: [n: %{type: :float}]})
      assert Parser.parse(spec, ["-1.5"]) == {[], %{n: -1.5}, %{}, []}
      assert Parser.parse(spec, ["-0.001"]) == {[], %{n: -0.001}, %{}, []}
    end
  end

  describe "opts - :short, :long attr" do
    test ":short" do
      spec = new_spec(%{opts: [opt: %{short: "o"}]})
      assert Parser.parse(spec, ["-o", "value"]) == {[], %{}, %{opt: "value"}, []}
    end

    test ":long" do
      spec = new_spec(%{opts: [opt: %{long: "opt"}]})
      assert Parser.parse(spec, ["--opt", "value"]) == {[], %{}, %{opt: "value"}, []}
    end

    test ":short and :long" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt"}]})
      assert Parser.parse(spec, ["-o", "value"]) == {[], %{}, %{opt: "value"}, []}
      assert Parser.parse(spec, ["--opt", "value"]) == {[], %{}, %{opt: "value"}, []}
    end
  end

  describe "opts - :type attr" do
    test "default to :string" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt"}]})
      assert Parser.parse(spec, ["-o", "value"]) == {[], %{}, %{opt: "value"}, []}
    end

    test ":string" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :string}]})
      assert Parser.parse(spec, ["--opt", "value"]) == {[], %{}, %{opt: "value"}, []}
      assert Parser.parse(spec, ["--opt=value"]) == {[], %{}, %{opt: "value"}, []}

      assert Parser.parse(spec, ["--opt="]) ==
               {[], %{}, %{opt: nil},
                [
                  {:missing_opt_value,
                   %{message: nil, type: :string, value: nil, action: :set, value_name: "OPT", prefixed_opt_name: "--opt"}}
                ]}

      assert Parser.parse(spec, ["--no-opt="]) == {[], %{}, %{opt: nil}, [{:unknown_opt, "--no-opt"}]}
    end

    test ":boolean" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :boolean}]})

      assert Parser.parse(spec, ["--opt"]) == {[], %{}, %{opt: true}, []}
      assert Parser.parse(spec, ["--opt", "true"]) == {[], %{}, %{opt: true}, [{:unknown_arg, "true"}]}
      assert Parser.parse(spec, ["--opt", "false"]) == {[], %{}, %{opt: true}, [{:unknown_arg, "false"}]}
      assert Parser.parse(spec, ["--opt", "other"]) == {[], %{}, %{opt: true}, [{:unknown_arg, "other"}]}

      assert Parser.parse(spec, ["--opt="]) == {[], %{}, %{opt: true}, []}
      assert Parser.parse(spec, ["--opt=true"]) == {[], %{}, %{opt: true}, []}
      assert Parser.parse(spec, ["--opt=false"]) == {[], %{}, %{opt: false}, []}

      assert Parser.parse(spec, ["--opt=other"]) ==
               {[], %{}, %{opt: false},
                [
                  {:invalid_opt,
                   %{message: nil, type: :boolean, value: "other", action: :set, value_name: "OPT", prefixed_opt_name: "--opt"}}
                ]}

      assert Parser.parse(spec, ["--no-opt"]) == {[], %{}, %{opt: false}, []}
      assert Parser.parse(spec, ["--no-opt", "true"]) == {[], %{}, %{opt: false}, [{:unknown_arg, "true"}]}
      assert Parser.parse(spec, ["--no-opt", "false"]) == {[], %{}, %{opt: false}, [{:unknown_arg, "false"}]}
      assert Parser.parse(spec, ["--no-opt", "other"]) == {[], %{}, %{opt: false}, [{:unknown_arg, "other"}]}

      assert Parser.parse(spec, ["--no-opt="]) == {[], %{}, %{opt: false}, []}

      assert Parser.parse(spec, ["--no-opt=true"]) ==
               {[], %{}, %{opt: false},
                [
                  {:invalid_opt,
                   %{
                     message: nil,
                     type: {:boolean, :negated},
                     value: "true",
                     action: :set,
                     value_name: "OPT",
                     prefixed_opt_name: "--no-opt"
                   }}
                ]}

      assert Parser.parse(spec, ["--no-opt=false"]) ==
               {[], %{}, %{opt: false},
                [
                  {:invalid_opt,
                   %{
                     message: nil,
                     type: {:boolean, :negated},
                     value: "false",
                     action: :set,
                     value_name: "OPT",
                     prefixed_opt_name: "--no-opt"
                   }}
                ]}

      assert Parser.parse(spec, ["--no-opt=other"]) ==
               {[], %{}, %{opt: false},
                [
                  {:invalid_opt,
                   %{
                     message: nil,
                     type: {:boolean, :negated},
                     value: "other",
                     action: :set,
                     value_name: "OPT",
                     prefixed_opt_name: "--no-opt"
                   }}
                ]}
    end

    test ":integer" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :integer}]})

      assert Parser.parse(spec, ["--opt"]) ==
               {[], %{}, %{opt: nil},
                [
                  {:missing_opt_value,
                   %{message: nil, type: :integer, value: nil, action: :set, value_name: "OPT", prefixed_opt_name: "--opt"}}
                ]}

      assert Parser.parse(spec, ["--opt", "30"]) == {[], %{}, %{opt: 30}, []}
      assert Parser.parse(spec, ["--opt", "-30"]) == {[], %{}, %{opt: -30}, []}

      assert Parser.parse(spec, ["--opt", "other"]) ==
               {[], %{}, %{opt: nil},
                [
                  invalid_opt: %{
                    message: nil,
                    type: :integer,
                    value: "other",
                    action: :set,
                    value_name: "OPT",
                    prefixed_opt_name: "--opt"
                  }
                ]}

      assert Parser.parse(spec, ["--opt="]) ==
               {[], %{}, %{opt: nil},
                [
                  missing_opt_value: %{
                    message: nil,
                    type: :integer,
                    value: nil,
                    action: :set,
                    value_name: "OPT",
                    prefixed_opt_name: "--opt"
                  }
                ]}

      assert Parser.parse(spec, ["--opt=30"]) == {[], %{}, %{opt: 30}, []}
      assert Parser.parse(spec, ["--opt=-30"]) == {[], %{}, %{opt: -30}, []}

      assert Parser.parse(spec, ["--opt=other"]) ==
               {[], %{}, %{opt: nil},
                [
                  invalid_opt: %{
                    message: nil,
                    type: :integer,
                    value: "other",
                    action: :set,
                    value_name: "OPT",
                    prefixed_opt_name: "--opt"
                  }
                ]}

      assert Parser.parse(spec, ["--no-opt="]) == {[], %{}, %{opt: nil}, [{:unknown_opt, "--no-opt"}]}

      assert Parser.parse(spec, ["-o"]) ==
               {[], %{}, %{opt: nil},
                [
                  missing_opt_value: %{message: nil, type: :integer, value: nil, action: :set, value_name: "OPT", prefixed_opt_name: "-o"}
                ]}

      assert Parser.parse(spec, ["-o", "30"]) == {[], %{}, %{opt: 30}, []}
      assert Parser.parse(spec, ["-o", "-30"]) == {[], %{}, %{opt: -30}, []}

      assert Parser.parse(spec, ["-o", "other"]) ==
               {[], %{}, %{opt: nil},
                [
                  invalid_opt: %{message: nil, type: :integer, value: "other", action: :set, value_name: "OPT", prefixed_opt_name: "-o"}
                ]}

      assert Parser.parse(spec, ["-o30"]) == {[], %{}, %{opt: 30}, []}
      assert Parser.parse(spec, ["-o-30"]) == {[], %{}, %{opt: -30}, []}
    end

    test ":float" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :float}]})

      assert Parser.parse(spec, ["--opt"]) ==
               {[], %{}, %{opt: nil},
                [
                  missing_opt_value: %{message: nil, type: :float, value: nil, action: :set, value_name: "OPT", prefixed_opt_name: "--opt"}
                ]}

      assert Parser.parse(spec, ["--opt", "30.0"]) == {[], %{}, %{opt: 30.0}, []}
      assert Parser.parse(spec, ["--opt", "-30.0"]) == {[], %{}, %{opt: -30.0}, []}

      assert Parser.parse(spec, ["--opt", "other"]) ==
               {[], %{}, %{opt: nil},
                [
                  invalid_opt: %{message: nil, type: :float, value: "other", action: :set, value_name: "OPT", prefixed_opt_name: "--opt"}
                ]}

      assert Parser.parse(spec, ["--opt="]) ==
               {[], %{}, %{opt: nil},
                [
                  missing_opt_value: %{message: nil, type: :float, value: nil, action: :set, value_name: "OPT", prefixed_opt_name: "--opt"}
                ]}

      assert Parser.parse(spec, ["--opt=30.0"]) == {[], %{}, %{opt: 30.0}, []}
      assert Parser.parse(spec, ["--opt=-30.0"]) == {[], %{}, %{opt: -30.0}, []}

      assert Parser.parse(spec, ["--opt=other"]) ==
               {[], %{}, %{opt: nil},
                [
                  invalid_opt: %{message: nil, type: :float, value: "other", action: :set, value_name: "OPT", prefixed_opt_name: "--opt"}
                ]}

      assert Parser.parse(spec, ["--no-opt="]) == {[], %{}, %{opt: nil}, [{:unknown_opt, "--no-opt"}]}

      assert Parser.parse(spec, ["-o"]) ==
               {[], %{}, %{opt: nil},
                [
                  missing_opt_value: %{message: nil, type: :float, value: nil, action: :set, value_name: "OPT", prefixed_opt_name: "-o"}
                ]}

      assert Parser.parse(spec, ["-o", "30.0"]) == {[], %{}, %{opt: 30.0}, []}
      assert Parser.parse(spec, ["-o", "-30.0"]) == {[], %{}, %{opt: -30.0}, []}

      assert Parser.parse(spec, ["-o", "other"]) ==
               {[], %{}, %{opt: nil},
                [
                  {:invalid_opt, %{message: nil, type: :float, value: "other", action: :set, value_name: "OPT", prefixed_opt_name: "-o"}}
                ]}

      assert Parser.parse(spec, ["-o30.0"]) == {[], %{}, %{opt: 30.0}, []}
      assert Parser.parse(spec, ["-o-30.0"]) == {[], %{}, %{opt: -30.0}, []}
    end
  end

  describe "opts - :action attr" do
    test "default to :set" do
      spec = new_spec(%{opts: [opt: %{short: "o"}]})
      assert Parser.parse(spec, ["-o", "value1", "-o", "value2"]) == {[], %{}, %{opt: "value2"}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", type: :boolean}]})
      assert Parser.parse(spec, ["-o", "-o"]) == {[], %{}, %{opt: true}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :boolean}]})
      assert Parser.parse(spec, ["-o", "--no-opt"]) == {[], %{}, %{opt: false}, []}
    end

    test ":set" do
      spec = new_spec(%{opts: [opt: %{short: "o", action: :set}]})
      assert Parser.parse(spec, ["-o", "value1", "-o", "value2"]) == {[], %{}, %{opt: "value2"}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", type: :boolean, action: :set}]})
      assert Parser.parse(spec, ["-o", "-o"]) == {[], %{}, %{opt: true}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :boolean, action: :set}]})
      assert Parser.parse(spec, ["-o", "--no-opt"]) == {[], %{}, %{opt: false}, []}
    end

    test ":count" do
      spec = new_spec(%{opts: [opt: %{short: "o", type: :boolean, action: :count}]})
      assert Parser.parse(spec, ["-o", "-o"]) == {[], %{}, %{opt: 2}, []}
    end

    test ":append" do
      spec = new_spec(%{opts: [opt: %{short: "o", action: :append}]})
      assert Parser.parse(spec, ["-o", "value", "-o", "value"]) == {[], %{}, %{opt: ["value", "value"]}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", type: :boolean, action: :append}]})
      assert Parser.parse(spec, ["-o", "-o"]) == {[], %{}, %{opt: [true, true]}, []}
    end
  end

  describe "opts - :default attr" do
  end

  describe "opts - :required attr" do
    test "default to false: missing opt falls back to default" do
      spec = new_spec(%{opts: [opt: %{long: "opt"}]})
      assert Parser.parse(spec, []) == {[], %{}, %{opt: nil}, []}
    end

    test "required: true with --long emits missing_required_opt when absent" do
      spec = new_spec(%{opts: [name: %{long: "name", required: true}]})

      assert Parser.parse(spec, []) ==
               {[], %{}, %{},
                [
                  {:missing_opt, %{message: nil, type: :string, value: nil, action: :set, value_name: "NAME", prefixed_opt_name: "--name"}}
                ]}
    end

    test "required: true with only -short uses -short in the error" do
      spec = new_spec(%{opts: [name: %{short: "n", required: true}]})

      assert Parser.parse(spec, []) ==
               {[], %{}, %{},
                [
                  {:missing_opt, %{message: nil, type: :string, value: nil, action: :set, value_name: "NAME", prefixed_opt_name: "-n"}}
                ]}
    end

    test "required: true with both -short and --long prefers --long in the error" do
      spec = new_spec(%{opts: [name: %{short: "n", long: "name", required: true}]})

      assert Parser.parse(spec, []) ==
               {[], %{}, %{},
                [
                  {:missing_opt, %{message: nil, type: :string, value: nil, action: :set, value_name: "NAME", prefixed_opt_name: "--name"}}
                ]}
    end

    test "required: true is satisfied when the opt is given" do
      spec = new_spec(%{opts: [name: %{long: "name", required: true}]})
      assert Parser.parse(spec, ["--name", "Joe"]) == {[], %{}, %{name: "Joe"}, []}
    end

    test "required: true coexists with other opts and errors are collected" do
      spec =
        new_spec(%{
          opts: [
            name: %{long: "name", required: true},
            age: %{long: "age", type: :integer}
          ]
        })

      assert Parser.parse(spec, ["--age", "30"]) ==
               {[], %{}, %{age: 30},
                [
                  {:missing_opt, %{message: nil, type: :string, value: nil, action: :set, value_name: "NAME", prefixed_opt_name: "--name"}}
                ]}
    end

    test "required: true with action: :append - never given is missing" do
      spec = new_spec(%{opts: [tag: %{long: "tag", action: :append, required: true}]})

      assert Parser.parse(spec, []) ==
               {[], %{}, %{},
                [
                  {:missing_opt, %{message: nil, type: :string, value: nil, action: :append, value_name: "TAG", prefixed_opt_name: "--tag"}}
                ]}

      assert Parser.parse(spec, ["--tag", "a", "--tag", "b"]) == {[], %{}, %{tag: ["a", "b"]}, []}
    end
  end

  test "collects multiple errors" do
    spec =
      new_spec(%{
        args: [
          born: %{}
        ],
        opts: [
          name: %{short: "n", long: "name", required: true},
          age: %{short: "a", long: "age", type: :integer},
          city: %{short: "c", long: "city"}
        ]
      })

    assert Parser.parse(spec, ["--unknown1", "--unknown2", "--age", "forever", "--city"]) ==
             {[], %{}, %{age: nil, city: nil},
              [
                unknown_opt: "--unknown1",
                unknown_opt: "--unknown2",
                invalid_opt: %{
                  message: nil,
                  type: :integer,
                  value: "forever",
                  action: :set,
                  value_name: "AGE",
                  prefixed_opt_name: "--age"
                },
                missing_opt_value: %{message: nil, type: :string, value: nil, action: :set, value_name: "CITY", prefixed_opt_name: "--city"},
                missing_opt: %{message: nil, type: :string, value: nil, action: :set, value_name: "NAME", prefixed_opt_name: "--name"},
                missing_arg: %{message: nil, type: :string, value: nil, nargs: :!, value_name: "BORN"}
              ]}
  end

  test "single '-' is handled as a normal argument" do
    spec =
      new_spec(%{
        args: [
          all: %{nargs: :*}
        ],
        opts: [
          input: %{short: "i"}
        ]
      })

    assert Parser.parse(spec, ["-", "-i", "-"]) == {[], %{all: ["-"]}, %{input: "-"}, []}
  end

  test "single '--' is handled as option terminator" do
    spec =
      new_spec(%{
        args: [
          all: %{nargs: :*}
        ],
        opts: [
          debug: %{short: "d", type: :boolean},
          single: %{short: "s", type: :boolean}
        ]
      })

    assert Parser.parse(spec, ["a1", "a2", "-d"]) == {[], %{all: ["a1", "a2"]}, %{debug: true, single: false}, []}
    assert Parser.parse(spec, ["a1", "a2", "--", "-d"]) == {[], %{all: ["a1", "a2", "-d"]}, %{debug: false, single: false}, []}
    assert Parser.parse(spec, ["a1", "a2", "-s"]) == {[], %{all: ["a1", "a2"]}, %{debug: false, single: true}, []}
    assert Parser.parse(spec, ["a1", "a2", "--", "-s"]) == {[], %{all: ["a1", "a2", "-s"]}, %{debug: false, single: false}, []}
  end

  defp new_spec(cmd_spec), do: Spec.new({:example, cmd_spec})
end
