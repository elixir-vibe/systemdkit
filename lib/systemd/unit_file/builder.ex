defmodule Systemd.UnitFile.Builder do
  @moduledoc """
  Typed builders for common systemd unit file sections.
  """

  alias Systemd.UnitFile

  @type directives :: keyword() | %{optional(atom() | String.t()) => term()}

  @doc """
  Builds a unit file from common `Unit`, `Service`, and `Install` sections.
  """
  @spec service(keyword()) :: UnitFile.t()
  def service(opts) when is_list(opts) do
    UnitFile.parse!("")
    |> maybe_append_section("Unit", Keyword.get(opts, :unit, []))
    |> maybe_append_section("Service", Keyword.get(opts, :service, []))
    |> maybe_append_section("Install", Keyword.get(opts, :install, []))
  end

  @doc """
  Builds a unit file with one section.
  """
  @spec section(String.t(), directives()) :: UnitFile.t()
  def section(name, directives) do
    UnitFile.parse!("")
    |> maybe_append_section(name, directives)
  end

  defp maybe_append_section(unit_file, _name, directives) when directives in [nil, [], %{}] do
    unit_file
  end

  defp maybe_append_section(unit_file, name, directives) do
    Enum.reduce(directives, unit_file, fn {directive, value}, unit_file ->
      append_directive(unit_file, name, normalize_name(directive), value)
    end)
  end

  defp append_directive(unit_file, section, name, values) when is_list(values) do
    Enum.reduce(values, unit_file, &UnitFile.append(&2, section, name, normalize_value(&1)))
  end

  defp append_directive(unit_file, section, name, value) do
    UnitFile.append(unit_file, section, name, normalize_value(value))
  end

  defp normalize_name(name) when is_atom(name) do
    name
    |> Atom.to_string()
    |> Macro.camelize()
  end

  defp normalize_name(name) when is_binary(name), do: name
  defp normalize_value(value) when is_binary(value), do: value
  defp normalize_value(value), do: to_string(value)
end
