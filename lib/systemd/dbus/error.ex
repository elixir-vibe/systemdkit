defmodule Systemd.DBus.Error do
  @moduledoc """
  Error returned by a D-Bus method call.
  """

  @type t :: %__MODULE__{
          name: String.t() | nil,
          message: String.t() | nil,
          body: [term()]
        }

  defstruct [:name, :message, body: []]
end
