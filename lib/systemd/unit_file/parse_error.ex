defmodule Systemd.UnitFile.ParseError do
  @moduledoc """
  Structured parser error for systemd unit files.
  """

  @type t :: %__MODULE__{
          reason: term(),
          rest: String.t(),
          line: pos_integer(),
          column: non_neg_integer()
        }

  defexception [:reason, :rest, :line, :column]

  @impl true
  def message(%__MODULE__{reason: reason, line: line, column: column}) do
    "invalid unit file at #{line}:#{column}: #{inspect(reason)}"
  end
end
