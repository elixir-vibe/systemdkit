defmodule Systemd.UnitFile.Comment do
  @moduledoc """
  Comment line in a systemd unit file.
  """

  alias Systemd.UnitFile.Span

  @type t :: %__MODULE__{marker: String.t(), text: String.t(), span: Span.t() | nil}

  defstruct marker: "#", text: "", span: nil
end
