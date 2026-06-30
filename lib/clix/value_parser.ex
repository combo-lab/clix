defmodule CLIX.ValueParser do
  @moduledoc """
  Built-in value parsers.

  Each parser accepts a `String.t()` and returns `{:ok, term()}` on success
  or `{:error, reason :: String.t()}` on failure.

  The error message should be a brief, value-agnostic reason.
  """

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
  def resolve_value_parser(sugar) when sugar in [:string, :integer, :float], do: {__MODULE__, sugar}
  def resolve_value_parser({mod, fun} = value_parser) when is_atom(mod) and is_atom(fun), do: value_parser
end
