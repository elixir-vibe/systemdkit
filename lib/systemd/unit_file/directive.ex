defmodule Systemd.UnitFile.Directive do
  @moduledoc """
  Key/value directive in a systemd unit file.

  Duplicate directives are valid and preserved.
  """

  @type t :: %__MODULE__{name: String.t(), value: String.t()}

  defstruct [:name, value: ""]
end
