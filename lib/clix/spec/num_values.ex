defmodule CLIX.Spec.NumValues do
  @moduledoc """
  Describes the number of values an arg or a value_opt consumes.

  Canonical and sugar forms are provided:

    * `{min, max}` (canonical) — consumes between `min` and `max` values.
    * `n` (sugar) — equivalent to `{n, n}` (exactly `n` values).

  `max` may be `:infinity` for unbounded consumption.
  """

  @type t :: canonical() | sugar()
  @type canonical :: {non_neg_integer(), non_neg_integer() | :infinity}
  @type sugar :: non_neg_integer()

  @doc false
  def check_type(n)
      when is_integer(n) and n >= 0,
      do: :ok

  def check_type({min, max})
      when is_integer(min) and min >= 0 and is_integer(max) and max >= 0 and min <= max,
      do: :ok

  def check_type({min, :infinity})
      when is_integer(min) and min >= 0,
      do: :ok

  def check_type(_) do
    expected_type = "a non-negative integer or a {min, max} tuple (min >= 0, max >= 0 or :infinity, min <= max)"
    {:error, expected_type}
  end
end
