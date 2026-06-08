defmodule Systemd.Manager do
  @moduledoc """
  Client for `org.freedesktop.systemd1.Manager`.
  """

  alias Systemd.{DBus, Error, Job, Unit, UnitObject}
  alias Systemd.TransientUnit.{AuxUnit, Property}

  @destination "org.freedesktop.systemd1"
  @path "/org/freedesktop/systemd1"
  @interface "org.freedesktop.systemd1.Manager"
  @default_mode "replace"

  @doc """
  Connects to the system bus.
  """
  @spec connect(keyword()) :: {:ok, pid()} | {:error, Error.t()}
  def connect(opts \\ []), do: DBus.connect(Keyword.get(opts, :bus, :system), opts)

  @doc """
  Lists currently loaded systemd units.

  Accepts either an existing D-Bus connection PID or connection options. Passing
  options opens a short-lived connection.
  """
  @spec list_units(pid() | keyword()) :: {:ok, [Unit.t()]} | {:error, Error.t()}
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

  @doc """
  Gets the D-Bus object path for a loaded unit.
  """
  @spec get_unit(pid(), String.t()) :: {:ok, UnitObject.t()} | {:error, Error.t()}
  def get_unit(conn, unit_name) when is_pid(conn) and is_binary(unit_name) do
    with {:ok, [object_path]} <- call(conn, "GetUnit", [unit_name], "s") do
      {:ok, %UnitObject{name: unit_name, object_path: object_path}}
    end
  end

  @doc """
  Starts a unit and returns the queued systemd job.
  """
  @spec start_unit(pid(), String.t(), keyword()) :: {:ok, Job.t()} | {:error, Error.t()}
  def start_unit(conn, unit_name, opts \\ []) do
    unit_operation(conn, "StartUnit", unit_name, opts)
  end

  @doc """
  Stops a unit and returns the queued systemd job.
  """
  @spec stop_unit(pid(), String.t(), keyword()) :: {:ok, Job.t()} | {:error, Error.t()}
  def stop_unit(conn, unit_name, opts \\ []) do
    unit_operation(conn, "StopUnit", unit_name, opts)
  end

  @doc """
  Restarts a unit and returns the queued systemd job.
  """
  @spec restart_unit(pid(), String.t(), keyword()) :: {:ok, Job.t()} | {:error, Error.t()}
  def restart_unit(conn, unit_name, opts \\ []) do
    unit_operation(conn, "RestartUnit", unit_name, opts)
  end

  @doc """
  Reloads a unit and returns the queued systemd job.
  """
  @spec reload_unit(pid(), String.t(), keyword()) :: {:ok, Job.t()} | {:error, Error.t()}
  def reload_unit(conn, unit_name, opts \\ []) do
    unit_operation(conn, "ReloadUnit", unit_name, opts)
  end

  @doc """
  Starts a transient unit and returns the queued systemd job.
  """
  @spec start_transient_unit(pid(), String.t(), [Property.t()], keyword()) ::
          {:ok, Job.t()} | {:error, Error.t()}
  def start_transient_unit(conn, unit_name, properties, opts \\ []) do
    mode = Keyword.get(opts, :mode, @default_mode)
    properties = Enum.map(properties, &Property.to_dbus/1)
    aux_units = opts |> Keyword.get(:aux_units, []) |> Enum.map(&AuxUnit.to_dbus/1)

    with {:ok, [object_path]} <-
           call(
             conn,
             "StartTransientUnit",
             [unit_name, mode, properties, aux_units],
             "ssa(sv)a(sa(sv))"
           ) do
      {:ok, %Job{object_path: object_path}}
    end
  end

  @doc """
  Reloads systemd manager configuration (`daemon-reload`).
  """
  @spec reload(pid()) :: :ok | {:error, Error.t()}
  def reload(conn) when is_pid(conn) do
    with {:ok, []} <- call(conn, "Reload"), do: :ok
  end

  defp unit_operation(conn, member, unit_name, opts) do
    mode = Keyword.get(opts, :mode, @default_mode)

    with {:ok, [object_path]} <- call(conn, member, [unit_name, mode], "ss") do
      {:ok, %Job{object_path: object_path}}
    end
  end

  defp call(conn, member, body \\ [], signature \\ "") do
    DBus.call_body(conn,
      destination: @destination,
      path: @path,
      interface: @interface,
      member: member,
      signature: signature,
      body: body
    )
  end
end
