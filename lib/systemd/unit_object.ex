defmodule Systemd.UnitObject do
  @moduledoc """
  D-Bus object for a loaded systemd unit.
  """

  alias Systemd.{Error, Properties, ServiceState, SocketState, TimerState, UnitState}

  @interface "org.freedesktop.systemd1.Unit"

  @enforce_keys [:object_path]
  @type t :: %__MODULE__{name: String.t() | nil, object_path: String.t()}

  defstruct [:name, :object_path]

  @doc false
  @spec new(String.t(), String.t() | nil) :: t()
  def new(object_path, name \\ nil) when is_binary(object_path) do
    %__MODULE__{name: name, object_path: object_path}
  end

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
  @spec state(pid(), t()) :: {:ok, UnitState.t()} | {:error, Error.t()}
  def state(conn, %__MODULE__{} = unit) do
    typed_state(conn, unit, @interface, UnitState)
  end

  @doc """
  Reads common service-specific properties.
  """
  @spec service_state(pid(), t()) :: {:ok, ServiceState.t()} | {:error, Error.t()}
  def service_state(conn, %__MODULE__{} = unit) do
    typed_state(conn, unit, "org.freedesktop.systemd1.Service", ServiceState)
  end

  @doc """
  Reads common socket-specific properties.
  """
  @spec socket_state(pid(), t()) :: {:ok, SocketState.t()} | {:error, Error.t()}
  def socket_state(conn, %__MODULE__{} = unit) do
    typed_state(conn, unit, "org.freedesktop.systemd1.Socket", SocketState)
  end

  @doc """
  Reads common timer-specific properties.
  """
  @spec timer_state(pid(), t()) :: {:ok, TimerState.t()} | {:error, Error.t()}
  def timer_state(conn, %__MODULE__{} = unit) do
    typed_state(conn, unit, "org.freedesktop.systemd1.Timer", TimerState)
  end

  defp typed_state(conn, unit, interface, module) do
    with {:ok, properties} <- Properties.get_all(conn, unit.object_path, interface) do
      {:ok, module.from_properties(properties)}
    end
  end
end
