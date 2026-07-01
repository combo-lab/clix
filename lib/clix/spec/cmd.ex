defmodule CLIX.Spec.Cmd do
  alias CLIX.Spec.{Arg, ValueOpt, FlagOpt}

  @enforce_keys [:name]
  defstruct [:name, :help, args: [], opts: [], cmds: []]

  @type t :: %__MODULE__{
          name: name(),
          help: String.t() | nil,
          args: [Arg.t()],
          opts: [ValueOpt.t() | FlagOpt.t()],
          cmds: [t()]
        }

  @typedoc """
  The command's name.

  The top-level cmd_name is the program name. If you name your CLI app as *example*,
  then you should set the name as `:example`.
  """
  @type name :: atom()

  @type config_entry ::
          {:help, String.t()}
          | {:args, [Arg.t()]}
          | {:opts, [ValueOpt.t() | FlagOpt.t()]}
          | {:cmds, [t()]}
  @type config :: [config_entry()]

  @spec new!(name(), config()) :: t()
  def new!(name, config) do
    Enum.each(config, fn entry -> check_config_entry!(entry) end)

    fields = Keyword.put(config, :name, name)
    struct!(__MODULE__, fields)
  end

  defp check_config_entry!({:help, value}) when is_binary(value), do: :ok

  defp check_config_entry!({:help = field, value}) do
    raise ArgumentError,
          "expected #{inspect(field)} to be a string, got: #{inspect(value)}"
  end

  defp check_config_entry!({:args, value}) when is_list(value), do: :ok

  defp check_config_entry!({:args = field, value}) do
    raise ArgumentError,
          "expected #{inspect(field)} to be a list, got: #{inspect(value)}"
  end

  defp check_config_entry!({:opts, value}) when is_list(value), do: :ok

  defp check_config_entry!({:opts = field, value}) do
    raise ArgumentError,
          "expected #{inspect(field)} to be a list, got: #{inspect(value)}"
  end

  defp check_config_entry!({:cmds, value}) when is_list(value), do: :ok

  defp check_config_entry!({:cmds = field, value}) do
    raise ArgumentError,
          "expected #{inspect(field)} to be a list, got: #{inspect(value)}"
  end

  defp check_config_entry!({field, value}) do
    raise ArgumentError,
          "unknown field #{inspect(field)} with value #{inspect(value)}"
  end
end
