# Changelog

## v0.1.4

- Added `Systemd.Calendar` helpers for typed daily, weekly, and monthly timer calendar expressions.

## v0.1.3

- Added `Systemd.UnitFile.equivalent?/2` for semantic unit file comparison after normalization.

## v0.1.2

- Added `Systemd.UnitName` helpers for formatting typed, template, and instance unit names.

## v0.1.1

- Renamed the OTP application from `:systemd` to `:systemdkit` so dependencies can use the normal `{:systemdkit, "~> 0.1.1"}` form.
- Renamed the GitHub repository to `elixir-vibe/systemdkit`.
- Kept public Elixir modules under the `Systemd.*` namespace.

## v0.1.0

First stable release.

- Added D-Bus-backed systemd manager APIs for unit lifecycle, unit-file operations, jobs, and signals.
- Added loss-aware systemd unit-file parsing and rendering.
- Added builders for service, socket, timer, mount, path, and target units.
- Added parser-backed validation for common unit-file directives, including resource-control and sandboxing settings.
- Added typed structs for units, jobs, unit-file operations, unit-file status, and unit/service/socket/timer state.
- Added transient-unit helpers, including resource-control properties.
- Added structured errors with permission/polkit classification.
- Added real Linux/systemd integration tests and documentation guides.

## v0.1.0-pre.1

- Removed VibeKit/Igniter scaffold dependencies from runtime package dependencies.

## v0.1.0-pre.0

Initial pre-release under the Hex package name `systemdkit`.

- Added D-Bus-backed systemd manager APIs.
- Added loss-aware systemd unit-file parser/generator.
- Added typed transient-unit contracts and unit-file operation results.
- Added structured errors with permission/polkit classification.
- Added typed unit/service/socket/timer state structs.
- Added parser-based directive value validation.
- Added Lima-backed integration test workflow.
