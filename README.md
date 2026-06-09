# systemdkit

Pure Elixir tools for systemd unit files and D-Bus manager control.

`systemdkit` is for Elixir applications and deployment tools that need to generate unit files, inspect systemd state, or control systemd directly over D-Bus without shelling out to `systemctl`.

## Installation

The Hex package is named `systemdkit`; the Mix application and modules are `:systemd` / `Systemd`.

```elixir
def deps do
  [
    {:systemd, "~> 0.1.0", hex: :systemdkit}
  ]
end
```

## Unit files

Build systemd units with typed helpers, render them, and validate them before installation:

```elixir
unit_file =
  Systemd.UnitFile.service(
    unit: [description: "My app", after: "network.target"],
    service: [
      type: :exec,
      user: "deploy",
      working_directory: "/opt/my-app/current",
      exec_start: "/opt/my-app/current/bin/my_app start",
      restart: "on-failure",
      memory_max: "512M",
      tasks_max: 512,
      no_new_privileges: true,
      protect_system: :strict
    ],
    install: [wanted_by: "multi-user.target"]
  )

:ok = Systemd.UnitFile.validate(unit_file, :service)
Systemd.UnitFile.to_string(unit_file)
```

Parsing is loss-aware: comments, blank lines, duplicate directives, reset directives, and source spans are preserved.

```elixir
{:ok, unit_file} = Systemd.UnitFile.parse("[Service]\nExecStart=/bin/true\n")
Systemd.UnitFile.get_all(unit_file, "Service", "ExecStart")
```

Builders are available for service, socket, timer, mount, path, and target units.

## D-Bus manager control

Use the top-level API for short-lived D-Bus operations:

```elixir
{:ok, units} = Systemd.list_units()
{:ok, unit_files} = Systemd.list_unit_files()
{:ok, state} = Systemd.unit_state("dbus.service")

:ok = Systemd.reload()
:ok = Systemd.start_unit("my_app.service")
:ok = Systemd.restart_unit("my_app.service")
```

Use `Systemd.Manager` when you want to reuse a connection or inspect jobs:

```elixir
Systemd.with_connection([], fn conn ->
  with {:ok, job} <- Systemd.Manager.restart_unit(conn, "my_app.service"),
       :ok <- Systemd.Job.await_signal(conn, job, timeout: 10_000) do
    :ok
  end
end)
```

## Errors and permissions

APIs return `{:ok, value}` or `{:error, %Systemd.Error{}}`. Permission and polkit failures are classified as `:permission`:

```elixir
case Systemd.start_unit("my_app.service") do
  :ok -> :ok
  {:error, error} ->
    if Systemd.Error.permission?(error), do: {:error, :permission_denied}, else: {:error, error}
end
```

Read-only calls often work unprivileged. Mutating system units typically require root or appropriate polkit rules. `systemdkit` reports those D-Bus errors directly; it does not retry through `sudo`.

For user units, pass `bus: :session` when a systemd user session bus is available:

```elixir
Systemd.list_units(bus: :session)
```

## Guides

- [D-Bus manager operations](guides/dbus-manager.md)
- [Xamal-style deployment units](guides/xamal-style-deployment.md)

## Integration testing

The test suite includes optional integration tests against a real Linux systemd manager. They are excluded by default:

```sh
mix test
```

Run them on Linux with systemd and a system bus:

```sh
SYSTEMD_INTEGRATION=1 mix test
```

This repository also includes a Lima helper used by maintainers:

```sh
scripts/integration_test.sh
```
