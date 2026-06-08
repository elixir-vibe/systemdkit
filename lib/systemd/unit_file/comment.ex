defmodule Systemd.UnitFile.Comment do
  @moduledoc """
  Comment line in a systemd unit file.
  """

  @type t :: %__MODULE__{marker: String.t(), text: String.t()}

  defstruct marker: "#", text: ""
end
