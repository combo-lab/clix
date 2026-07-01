defmodule CLIX.Spec.Arg do
  alias CLIX.Spec.NumValues
  alias CLIX.Spec.ValueParser

  @enforce_keys [:name, :value_parser]
  defstruct [
    :name,
    :help,
    :value_name,
    :fold,
    :num_values,
    :value_parser,
    :required,
    :default_value
  ]

  @type name :: atom()

  @type fold :: :replace | :accumulate
  @folds [:replace, :accumulate]

  @type t :: %__MODULE__{
          name: name(),
          help: String.t() | nil,
          value_name: String.t(),
          fold: fold(),
          num_values: NumValues.t(),
          value_parser: ValueParser.t(),
          required: boolean(),
          default_value: String.t() | nil
        }

  @type config_entry ::
          {:value_name, String.t()}
          | {:help, String.t()}
          | {:fold, fold()}
          | {:num_values, NumValues.t()}
          | {:value_parser, ValueParser.t()}
          | {:required, boolean()}
          | {:default_value, String.t()}

  @type config :: [config_entry()]

  @spec new!(name(), config()) :: t()
  def new!(name, config) do
    Enum.each(config, fn entry -> check_config_entry!(entry) end)

    default_config = [
      name: name,
      value_name: name |> to_string() |> String.upcase(),
      help: nil,
      fold: :replace,
      num_values: {1, 1},
      value_parser: :string,
      required: true,
      default_value: nil
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

  defp check_config_entry!({:value_name, value}) when is_binary(value), do: :ok

  defp check_config_entry!({:value_name = field, value}) do
    raise ArgumentError,
          "expected #{inspect(field)} to be a string, got: #{inspect(value)}"
  end

  defp check_config_entry!({:fold, value}) when value in @folds, do: :ok

  defp check_config_entry!({:fold = field, value}) do
    raise ArgumentError,
          "expected #{inspect(field)} to be one of #{inspect(@folds)}, got: #{inspect(value)}"
  end

  defp check_config_entry!({:num_values = field, value}) do
    case NumValues.check_type(value) do
      :ok ->
        :ok

      {:error, expected_type} ->
        raise ArgumentError, "expected #{inspect(field)} to be #{expected_type}, got: #{inspect(value)}"
    end
  end

  defp check_config_entry!({:value_parser = field, value}) do
    case ValueParser.check_type(value) do
      :ok ->
        :ok

      {:error, expected_type} ->
        raise ArgumentError, "expected #{inspect(field)} to be #{expected_type}, got: #{inspect(value)}"
    end
  end

  defp check_config_entry!({:required, value}) when is_boolean(value), do: :ok

  defp check_config_entry!({:required = field, value}) do
    raise ArgumentError,
          "expected #{inspect(field)} to be a boolean, got: #{inspect(value)}"
  end

  defp check_config_entry!({:default_value, value}) when is_binary(value), do: :ok

  defp check_config_entry!({:default_value = field, value}) do
    raise ArgumentError,
          "expected #{inspect(field)} to be a string, got: #{inspect(value)}"
  end

  defp check_config_entry!({field, value}) do
    raise ArgumentError,
          "unknown field #{inspect(field)} with value #{inspect(value)}"
  end
end
