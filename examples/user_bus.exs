# Requires a user session bus, usually available under a graphical or lingering
# systemd user session.
{:ok, conn} = Systemd.Manager.connect(bus: :session)
{:ok, units} = Systemd.Manager.list_units(conn)

units
|> Enum.take(10)
|> Enum.each(&IO.puts(&1.name))
