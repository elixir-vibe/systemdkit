defmodule Systemd.UnitObject do
  @moduledoc """
  D-Bus object for a loaded systemd unit.
  """

  alias Systemd.{Error, Properties}

  @interface "org.freedesktop.systemd1.Unit"

  @type t :: %__MODULE__{name: String.t() | nil, object_path: String.t()}

  defstruct [:name, :object_path]

  @doc """
  Reads one property from the unit object.
  """
  @spec property(pid(), t(), String.t()) :: {:ok, term()} | {:error, Error.t()}
  def property(conn, %__MODULE__{object_path: path}, property) do
    Properties.get(conn, path, @interface, property)
  end

  @doc """
  Reads common unit state properties.
  """
  @spec state(pid(), t()) :: {:ok, map()} | {:error, Error.t()}
  def state(conn, %__MODULE__{} = unit) do
    with {:ok, properties} <- Properties.get_all(conn, unit.object_path, @interface) do
      {:ok,
       %{
         id: Map.get(properties, "Id"),
         load_state: Map.get(properties, "LoadState"),
         active_state: Map.get(properties, "ActiveState"),
         sub_state: Map.get(properties, "SubState"),
         main_pid: Map.get(properties, "MainPID"),
         fragment_path: Map.get(properties, "FragmentPath")
       }}
    end
  end
end
