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

  alias __MODULE__.Types
  alias __MODULE__.Semantics
  alias __MODULE__.Normalization

  @doc """
  Builds a spec from raw data.
  """
  # TODO: replace returned term() with CLIX.Spec.Cmd.t()
  @spec new!(input :: term()) :: term()
  def new!({cmd_name, cmd_spec}) do
    cmd_path = []
    Types.check!({cmd_name, cmd_spec}, cmd_path)
    Semantics.check!({cmd_name, cmd_spec}, cmd_path)
    Normalization.normalize({cmd_name, cmd_spec})
  end

  def new!(input) do
    raise ArgumentError,
          location([], :cmd) <>
            "expected a {cmd_name, cmd_spec} tuple, got: #{inspect(input)}"
  end

  @doc false
  def value_actions, do: @value_actions

  @doc false
  def flag_actions, do: @flag_actions

  @doc false
  def location(cmd_path, :cmd) when is_list(cmd_path) do
    "under the cmd path #{inspect(Enum.reverse(cmd_path))} - "
  end

  def location(cmd_path, {:arg, arg_name}) when is_list(cmd_path) do
    "arg #{inspect(arg_name)} under the cmd path #{inspect(Enum.reverse(cmd_path))} - "
  end

  def location(cmd_path, {:opt, opt_name}) when is_list(cmd_path) do
    "opt #{inspect(opt_name)} under the cmd path #{inspect(Enum.reverse(cmd_path))} - "
  end
end
