defmodule Systemd.SocketState do
  @moduledoc """
  Common state properties for a systemd socket object.
  """

  @type t :: %__MODULE__{
          result: String.t() | nil,
          listen: [term()] | nil,
          accept: boolean() | nil,
          n_connections: non_neg_integer() | nil
        }

  defstruct [:result, :listen, :accept, :n_connections]

  @doc false
  @spec from_properties(map()) :: t()
  def from_properties(properties) when is_map(properties) do
    %__MODULE__{
      result: Map.get(properties, "Result"),
      listen: Map.get(properties, "Listen"),
      accept: Map.get(properties, "Accept"),
      n_connections: Map.get(properties, "NConnections")
    }
  end
end
