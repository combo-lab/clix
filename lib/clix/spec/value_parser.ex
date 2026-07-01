defmodule CLIX.Spec.ValueParser do
  @moduledoc """
  Describes the value parser.

  Each parser accepts a `String.t()` and returns `{:ok, term()}` on success
  or `{:error, reason :: String.t()}` on failure.

  The error message should be a brief, value-agnostic reason.
  """

  @type t :: mfa_remote() | mfa_local() | mfa_local_bare()

  @type mfa_remote :: {mod(), fun(), args()}
  @type mfa_local :: {fun(), args()}
  @type mfa_local_bare :: fun()

  @type mod :: atom()
  @type fun :: atom()
  @type args :: [term()]

  @spec string(String.t()) :: {:ok, String.t()}
  def string(s), do: {:ok, s}

  @spec integer(String.t()) :: {:ok, integer()} | {:error, String.t()}
  def integer(s) do
    case Integer.parse(s) do
      {n, ""} -> {:ok, n}
      _ -> {:error, "not a valid integer"}
    end
  end

  @spec float(String.t()) :: {:ok, float()} | {:error, String.t()}
  def float(s) do
    case Float.parse(s) do
      {f, ""} -> {:ok, f}
      _ -> {:error, "not a valid float"}
    end
  end

  @doc false
  def check_type({mod, fun, args}) when is_atom(mod) and is_atom(fun) and is_list(args), do: :ok
  def check_type({fun, args}) when is_atom(fun) and is_list(args), do: :ok
  def check_type(fun) when is_atom(fun), do: :ok

  def check_type(_) do
    expected_type = "a {mod, fun, args} tuple, a {fun, args} tuple, or a fun as atom"
    {:error, expected_type}
  end

  @doc false
  def resolve_mfa({mod, fun, args}) when is_atom(mod) and is_atom(fun) and is_list(args),
    do: {mod, fun, args}

  def resolve_mfa({fun, args}) when is_atom(fun) and is_list(args),
    do: {__MODULE__, fun, args}

  def resolve_mfa(fun) when is_atom(fun),
    do: {__MODULE__, fun, []}

  @doc false
  def parse({mod, fun, args}, raw) do
    apply(mod, fun, [raw | args])
  end
end
