defmodule Systemd.Manager do
  @moduledoc """
  Client for `org.freedesktop.systemd1.Manager`.
  """

  alias Systemd.DBus
  alias Systemd.Unit

  @destination "org.freedesktop.systemd1"
  @path "/org/freedesktop/systemd1"
  @interface "org.freedesktop.systemd1.Manager"

  @doc """
  Connects to the system bus.
  """
  @spec connect(keyword()) :: {:ok, pid()} | {:error, term()}
  def connect(opts \\ []), do: DBus.connect(Keyword.get(opts, :bus, :system), opts)

  @doc """
  Lists currently loaded systemd units.

  Accepts either an existing D-Bus connection PID or connection options. Passing
  options opens a short-lived connection.
  """
  @spec list_units(pid() | keyword()) :: {:ok, [Unit.t()]} | {:error, term()}
  def list_units(conn_or_opts \\ [])

  def list_units(conn) when is_pid(conn) do
    with {:ok, [units]} <- call(conn, "ListUnits") do
      {:ok, Enum.map(units, &Unit.from_list_units_row/1)}
    end
  end

  def list_units(opts) when is_list(opts) do
    with {:ok, conn} <- connect(opts) do
      list_units(conn)
    end
  end

  defp call(conn, member, body \\ [], signature \\ "") do
    DBus.call(conn,
      destination: @destination,
      path: @path,
      interface: @interface,
      member: member,
      signature: signature,
      body: body
    )
  end
end
