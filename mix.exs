defmodule Systemd.MixProject do
  use Mix.Project

  @version "0.1.0-pre.0"
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

  # Run "mix help compile.app" to learn about applications.
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

  # Run "mix help deps" to learn about dependencies.
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
      {:vibe_kit, "== 0.1.2"},
      {:igniter, "~> 0.6", only: [:dev, :test]}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package do
    [
      name: "systemdkit",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
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
