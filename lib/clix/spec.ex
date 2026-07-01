defmodule CLIX.Spec do
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
        @cli_spec cmd(:my_cli, [...])
      end

  Elixir evaluates the right-hand side of `@cli_spec` when the module is
  compiled and inlines the resulting spec wherever `@cli_spec` is referenced.

  An invalid spec will fail `mix compile` with the same `ArgumentError` you'd
  see at runtime.
  """

  alias __MODULE__.Cmd
  alias __MODULE__.Arg
  alias __MODULE__.ValueOpt
  alias __MODULE__.FlagOpt

  def cmd(name, config \\ []), do: Cmd.new!(name, config)
  def arg(name, config \\ []), do: Arg.new!(name, config)
  def value_opt(name, config \\ []), do: ValueOpt.new!(name, config)
  def flag_opt(name, config \\ []), do: FlagOpt.new!(name, config)
end
