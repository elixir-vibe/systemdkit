# Systemd

Pure Elixir tools for working with systemd.

Hex package name: `systemdkit`. The Mix application and public modules remain `:systemd` / `Systemd`.

```elixir
{:systemdkit, "~> 0.1.0-pre"}
```

The package exposes a small D-Bus backed manager client:

```elixir
{:ok, conn} = Systemd.Manager.connect()
{:ok, units} = Systemd.Manager.list_units(conn)
{:ok, unit} = Systemd.Manager.get_unit(conn, "dbus.service")
{:ok, state} = Systemd.UnitObject.state(conn, unit)
{:ok, service_state} = Systemd.UnitObject.service_state(conn, unit)
```

It also includes a NimbleParsec-backed unit file parser/generator:

```elixir
{:ok, unit_file} = Systemd.UnitFile.parse("[Service]\nExecStart=/bin/app start\n")
Systemd.UnitFile.to_string(unit_file)

unit_file =
  Systemd.UnitFile.service(
    unit: [description: "My app"],
    service: [exec_start: "/bin/app start", restart: :always],
    install: [wanted_by: "multi-user.target"]
  )
```

The package depends on [`rebus`](https://hex.pm/packages/rebus) for the D-Bus wire protocol instead of shelling out to `systemctl`.

APIs return idiomatic `{:ok, value}` / `{:error, %Systemd.Error{}}` tuples. Permission and polkit failures are classified with `category: :permission` and can be checked with `Systemd.Error.permission?/1`.

See `examples/` for service, timer, and user-bus snippets, and `guides/xamal-style-deployment.md` for a deployment-oriented template unit example.

## Permissions

Systemd control happens over D-Bus. Read-only calls such as listing units usually work as an unprivileged user. Mutating calls such as daemon reload, starting system units, enabling units, or writing to `/etc/systemd/system` may require root or a polkit rule for the caller. The package returns structured `Systemd.Error` values for D-Bus policy failures instead of retrying through `sudo`.

For user units, pass `bus: :session` when a systemd user session bus is available:

```elixir
Systemd.list_units(bus: :session)
```

## Unit files

`Systemd.UnitFile` preserves comments, blank lines, duplicate directives, reset directives, and source spans. Validation is intentionally separate from parsing and includes directive-specific value checks for common service, socket, timer, and install keys:

```elixir
unit_file = Systemd.UnitFile.parse!("[Service]\nExecStart=/bin/true\n")
:ok = Systemd.UnitFile.validate(unit_file, :service)
```

## Development

```sh
mix deps.get
mix ci
```

Integration tests are excluded by default because they require Linux with systemd and a system bus. For local development, run them inside the Lima Debian VM named `systemd-test`:

```sh
~/.local/bin/limactl shell systemd-test
cd /Users/dannote/Development/systemd
SYSTEMD_INTEGRATION=1 mix test
```

Or from macOS, copy the source into the VM and run the full integration suite:

```sh
scripts/integration_test.sh
```

Quick VM checks:

```sh
~/.local/bin/limactl shell systemd-test -- systemctl is-system-running
~/.local/bin/limactl shell systemd-test -- busctl --system list --no-pager
```

See `CONTRIBUTING.md` before publishing a release.
