defmodule Systemd.UnitFile.Directive do
  @moduledoc """
  Key/value directive in a systemd unit file.

  Duplicate directives are valid and preserved.
  """

  alias Systemd.UnitFile.Span

  @type t :: %__MODULE__{name: String.t(), value: String.t(), span: Span.t() | nil}

  defstruct [:name, :span, value: ""]
end
