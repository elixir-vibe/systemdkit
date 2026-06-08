# Systemd

Pure Elixir tools for working with systemd.

The current spike exposes a small D-Bus backed manager client:

```elixir
{:ok, conn} = Systemd.Manager.connect()
{:ok, units} = Systemd.Manager.list_units(conn)
```

The package depends on [`rebus`](https://hex.pm/packages/rebus) for the D-Bus wire protocol instead of shelling out to `systemctl`.

## Development

```sh
mix deps.get
mix ci
```

Integration tests are excluded by default because they require Linux with systemd and a system bus:

```sh
SYSTEMD_INTEGRATION=1 mix test
```
