defmodule Systemd.DBus.Result do
  @moduledoc """
  Successful D-Bus method call result.
  """

  @type t :: %__MODULE__{
          body: [term()],
          message: Rebus.Message.t()
        }

  defstruct [:message, body: []]
end
