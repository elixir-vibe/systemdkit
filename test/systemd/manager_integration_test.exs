defmodule Systemd.ManagerIntegrationTest do
  use ExUnit.Case, async: false

  alias Systemd.{
    Error,
    Job,
    JobStatus,
    Manager,
    Properties,
    TransientUnit,
    Unit,
    UnitFileOperation,
    UnitFileStatus,
    UnitObject
  }

  @moduletag :integration

  test "lists units from a real systemd manager over the system bus" do
    assert File.exists?("/run/dbus/system_bus_socket")

    assert {:ok, units} = Manager.list_units()
    assert Enum.any?(units, &match?(%Unit{name: "dbus.service"}, &1))
    assert Enum.any?(units, &(&1.name == "init.scope" or &1.name == "-.slice"))
  end

  test "lists queued jobs" do
    assert {:ok, conn} = Manager.connect()
    assert {:ok, jobs} = Manager.list_jobs(conn)
    assert Enum.all?(jobs, &match?(%JobStatus{}, &1))
  end

  test "lists unit files and reads unit-file state" do
    assert {:ok, conn} = Manager.connect()

    assert {:ok, unit_files} = Manager.list_unit_files(conn)

    assert Enum.any?(unit_files, fn %UnitFileStatus{path: path, state: state} ->
             is_binary(path) and String.ends_with?(path, ".service") and is_binary(state)
           end)

    assert {:ok, state} = Manager.unit_file_state(conn, "dbus.service")
    assert is_binary(state)
  end

  test "gets a unit object and reads common properties" do
    assert {:ok, conn} = Manager.connect()
    assert {:ok, %UnitObject{} = unit} = Manager.get_unit(conn, "dbus.service")
    assert {:ok, state} = UnitObject.state(conn, unit)

    assert state.id == "dbus.service"
    assert state.load_state == "loaded"
    assert state.active_state in ["active", "activating", "inactive"]
  end

  test "daemon reload is available or reports policy denial" do
    assert {:ok, conn} = Manager.connect()

    case Manager.reload(conn) do
      :ok ->
        :ok

      {:error,
       %Systemd.Error{dbus_name: "org.freedesktop.DBus.Error.InteractiveAuthorizationRequired"}} ->
        :ok
    end
  end

  test "unit-file mutating operations return typed changes or policy denial" do
    assert {:ok, conn} = Manager.connect()

    name = "systemd-elixir-file-test-#{System.unique_integer([:positive])}.service"
    path = Path.join(System.tmp_dir!(), name)

    File.write!(path, "[Service]\nType=oneshot\nExecStart=/bin/true\n")

    try do
      case Manager.link_unit_files(conn, [path], runtime: true, force: true) do
        {:ok, %UnitFileOperation{}} ->
          assert_operation_or_permission(
            Manager.enable_unit_files(conn, [name], runtime: true, force: true)
          )

          assert_operation_or_permission(Manager.disable_unit_files(conn, [name], runtime: true))

          assert_operation_or_permission(
            Manager.mask_unit_files(conn, [name], runtime: true, force: true)
          )

          assert_operation_or_permission(Manager.unmask_unit_files(conn, [name], runtime: true))

        {:error, %Error{} = error} ->
          assert Error.permission?(error)
      end
    after
      File.rm(path)
    end
  end

  test "starts a transient unit with resource controls" do
    assert {:ok, conn} = Manager.connect()

    name = "systemd-elixir-resource-test-#{System.unique_integer([:positive])}.service"

    properties = [
      TransientUnit.string("Description", "systemd Elixir resource integration test"),
      TransientUnit.string("Type", "oneshot"),
      TransientUnit.boolean("RemainAfterExit", true),
      TransientUnit.memory_max(67_108_864),
      TransientUnit.tasks_max(64),
      TransientUnit.exec_start("/bin/true", ["/bin/true"])
    ]

    case Manager.start_transient_unit(conn, name, properties) do
      {:ok, %Job{} = job} ->
        assert :ok = Job.await(conn, job, timeout: 5_000)
        assert {:ok, unit} = Manager.get_unit(conn, name)

        assert {:ok, 67_108_864} =
                 Properties.get(
                   conn,
                   unit.object_path,
                   "org.freedesktop.systemd1.Service",
                   "MemoryMax"
                 )

        assert :ok = Manager.stop_unit(conn, name) |> await_or_ok(conn)

      {:error, %Error{} = error} ->
        assert Error.permission?(error)
    end
  end

  test "starts and awaits a harmless transient unit" do
    assert {:ok, conn} = Manager.connect()

    name = "systemd-elixir-test-#{System.unique_integer([:positive])}.service"

    properties = [
      TransientUnit.string("Description", "systemd Elixir integration test"),
      TransientUnit.string("Type", "oneshot"),
      TransientUnit.exec_start("/bin/true", ["/bin/true"])
    ]

    case Manager.start_transient_unit(conn, name, properties) do
      {:ok, %Job{} = job} ->
        assert :ok = Job.await(conn, job, timeout: 5_000)

      {:error,
       %Systemd.Error{dbus_name: "org.freedesktop.DBus.Error.InteractiveAuthorizationRequired"}} ->
        :ok
    end
  end

  defp await_or_ok({:ok, %Job{} = job}, conn), do: Job.await(conn, job, timeout: 5_000)
  defp await_or_ok({:error, %Error{} = error}, _conn), do: {:error, error}

  defp assert_operation_or_permission({:ok, %UnitFileOperation{changes: changes}})
       when is_list(changes), do: :ok

  defp assert_operation_or_permission({:error, %Error{} = error}),
    do: assert(Error.permission?(error))
end
