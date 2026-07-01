defmodule CLIX.Spec.FlagOpt do
  @enforce_keys [:name, :help, :short, :long, :fold, :default, :active]
  defstruct @enforce_keys

  @type name :: atom()

  @type fold :: :replace | :count
  @folds [:replace, :count]

  @type t :: %__MODULE__{
          name: name(),
          help: String.t() | nil,
          short: String.t(),
          long: String.t(),
          fold: fold(),
          default: term(),
          active: term()
        }

  @type config_entry ::
          {:help, String.t()}
          | {:short, String.t()}
          | {:long, String.t()}
          | {:fold, fold()}
          | {:default, term()}
          | {:active, term()}

  @type config :: [config_entry()]

  @spec new!(name(), config()) :: t()
  def new!(name, config) do
    Enum.each(config, fn entry -> check_config_entry!(entry) end)

    default_config = [
      name: name,
      help: nil,
      short: nil,
      long: nil,
      fold: :replace,
      default: false,
      active: true
    ]

    fields =
      default_config
      |> Keyword.merge(config)

    struct!(__MODULE__, fields)
  end

  defp check_config_entry!({:help, value}) when is_binary(value), do: :ok

  defp check_config_entry!({:help = field, value}) do
    raise ArgumentError,
          "expected #{inspect(field)} to be a string, got: #{inspect(value)}"
  end

  defp check_config_entry!({:short = field, value}) when is_binary(value) do
    cond do
      String.length(value) != 1 ->
        raise ArgumentError,
              "expected #{inspect(field)} to be a single-character string, got: #{inspect(value)}"

      String.match?(value, ~r/^[\d\-=\s]$/) ->
        raise ArgumentError,
              "expected #{inspect(field)} to not be a digit, '-', '=', or whitespace, got: #{inspect(value)}"

      true ->
        :ok
    end
  end

  defp check_config_entry!({:short = field, value}) do
    raise ArgumentError,
          "expected #{inspect(field)} to be a single-character string, got: #{inspect(value)}"
  end

  defp check_config_entry!({:long = field, value}) when is_binary(value) do
    cond do
      String.length(value) < 2 ->
        raise ArgumentError,
              "expected #{inspect(field)} to be a string of length >= 2, got: #{inspect(value)}"

      String.starts_with?(value, "-") ->
        raise ArgumentError,
              "expected #{inspect(field)} to not start with '-', got: #{inspect(value)}"

      String.contains?(value, "=") ->
        raise ArgumentError,
              "expected #{inspect(field)} to not contain '=', got: #{inspect(value)}"

      String.match?(value, ~r/\s/) ->
        raise ArgumentError,
              "expected #{inspect(field)} to not contain whitespace, got: #{inspect(value)}"

      true ->
        :ok
    end
  end

  defp check_config_entry!({:long = field, value}) do
    raise ArgumentError,
          "expected #{inspect(field)} to be a string of length >= 2, got: #{inspect(value)}"
  end

  defp check_config_entry!({:fold, value}) when value in @folds, do: :ok

  defp check_config_entry!({:fold = field, value}) do
    raise ArgumentError,
          "expected #{inspect(field)} to be one of #{inspect(@folds)}, got: #{inspect(value)}"
  end

  defp check_config_entry!({:default, _}), do: :ok

  defp check_config_entry!({:active, _}), do: :ok

  defp check_config_entry!({field, value}) do
    raise ArgumentError,
          "unknown field #{inspect(field)} with value #{inspect(value)}"
  end
end
