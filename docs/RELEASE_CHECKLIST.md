# Release Checklist

Before publishing a pre-release or Hex package:

- Run `mix ci` locally.
- Run `mix docs` and inspect generated module examples.
- Run `scripts/integration_test.sh` against the Lima systemd VM.
- Confirm public APIs return `{:ok, value}` or `{:error, %Systemd.Error{}}`.
- Confirm mutating D-Bus calls classify permission and polkit failures as `:permission`.
- Review package metadata in `mix.exs` for version, links, licenses, and files.
- Tag the release from a clean git working tree.
