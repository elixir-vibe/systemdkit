defmodule Systemd.UnitName do
  @moduledoc """
  Pure helpers for formatting systemd unit names.

  Systemd unit names are ordinary strings, but callers often need to format the
  same patterns repeatedly: typed names such as `dbus.service`, template names
  such as `my_app@.service`, and instance names such as `my_app@4000.service`.

  This module keeps that formatting explicit without introducing a struct or a
  deployment-specific abstraction.

  ## Examples

      iex> Systemd.UnitName.new("dbus", :service)
      "dbus.service"

      iex> Systemd.UnitName.template("my_app", :service)
      "my_app@.service"

      iex> Systemd.UnitName.instance("my_app", 4000, :service)
      "my_app@4000.service"

      iex> Systemd.UnitName.ensure_type("my_app@4000", :service)
      "my_app@4000.service"

      iex> Systemd.UnitName.drop_type("my_app@4000.service")
      "my_app@4000"
  """

  @type unit_type :: :service | :socket | :timer | :target | :mount | :path | String.t()

  @doc """
  Formats a typed systemd unit name.

  If `name` already ends with the requested type suffix, it is returned
  unchanged.
  """
  @spec new(String.t(), unit_type()) :: String.t()
  def new(name, type) when is_binary(name), do: ensure_type(name, type)

  @doc """
  Formats a systemd template unit name.
  """
  @spec template(String.t(), unit_type()) :: String.t()
  def template(name, type) when is_binary(name) do
    name
    |> base_name()
    |> Kernel.<>("@")
    |> ensure_type(type)
  end

  @doc """
  Formats a systemd instance unit name.
  """
  @spec instance(String.t(), String.Chars.t(), unit_type()) :: String.t()
  def instance(name, instance, type) when is_binary(name) do
    base = base_name(name)
    instance = to_string(instance)

    base
    |> Kernel.<>("@" <> instance)
    |> ensure_type(type)
  end

  @doc """
  Ensures a unit name has the suffix for `type`.
  """
  @spec ensure_type(String.t(), unit_type()) :: String.t()
  def ensure_type(name, type) when is_binary(name) do
    suffix = suffix(type)

    if String.ends_with?(name, suffix) do
      name
    else
      name <> suffix
    end
  end

  @doc """
  Drops the final systemd unit type suffix from a name.
  """
  @spec drop_type(String.t()) :: String.t()
  def drop_type(name) when is_binary(name) do
    Enum.reduce_while(known_suffixes(), name, fn suffix, name ->
      if String.ends_with?(name, suffix) do
        {:halt, String.trim_trailing(name, suffix)}
      else
        {:cont, name}
      end
    end)
  end

  defp base_name(name) do
    name
    |> drop_type()
    |> String.trim_trailing("@")
  end

  defp known_suffixes do
    ~w(.service .socket .timer .target .mount .path)
  end

  defp suffix(type) when is_atom(type), do: "." <> Atom.to_string(type)

  defp suffix(type) when is_binary(type) do
    type = String.trim_leading(type, ".")
    "." <> type
  end
end
