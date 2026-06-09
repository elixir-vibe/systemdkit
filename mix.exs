defmodule Systemd.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/elixir-vibe/systemd"

  def project do
    [
      app: :systemd,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "Pure Elixir tools for systemd unit files and D-Bus manager control",
      package: package(),
      docs: docs(),
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :rebus]
    ]
  end

  def cli do
    [
      preferred_envs: [ci: :test]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.38", only: :dev, runtime: false},
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.0", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:nimble_parsec, "~> 1.4"},
      {:rebus, "~> 0.2.0"},
      {:vibe_kit, "== 0.1.2", only: [:dev, :test], runtime: false},
      {:igniter, "~> 0.6", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      name: "systemdkit",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib guides examples .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE",
        "guides/xamal-style-deployment.md",
        "guides/dbus-manager.md"
      ],
      groups_for_extras: [Guides: ~r/guides\//],
      groups_for_modules: [
        "D-Bus": [
          Systemd.DBus,
          Systemd.DBus.Result,
          Systemd.Manager,
          Systemd.Signal,
          Systemd.Properties
        ],
        "Unit files": [
          Systemd.UnitFile,
          Systemd.UnitFile.Blank,
          Systemd.UnitFile.Builder,
          Systemd.UnitFile.Comment,
          Systemd.UnitFile.Directive,
          Systemd.UnitFile.ParseError,
          Systemd.UnitFile.Raw,
          Systemd.UnitFile.Section,
          Systemd.UnitFile.Span,
          Systemd.UnitFile.ValidationError,
          Systemd.UnitFile.Value
        ],
        "Runtime structs": [
          Systemd.Error,
          Systemd.Job,
          Systemd.JobStatus,
          Systemd.ServiceState,
          Systemd.SocketState,
          Systemd.TimerState,
          Systemd.Unit,
          Systemd.UnitFileChange,
          Systemd.UnitFileOperation,
          Systemd.UnitFileStatus,
          Systemd.UnitObject,
          Systemd.UnitState
        ],
        "Transient units": [
          Systemd.TransientUnit,
          Systemd.TransientUnit.AuxUnit,
          Systemd.TransientUnit.Property
        ]
      ]
    ]
  end

  defp aliases() do
    [
      ci: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test",
        "credo --strict",
        "dialyzer",
        "ex_dna --max-clones 0",
        "reach.check --arch --smells"
      ]
    ]
  end
end
