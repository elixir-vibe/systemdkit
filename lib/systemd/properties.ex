defmodule Systemd.Properties do
  @moduledoc """
  Client for `org.freedesktop.DBus.Properties`.
  """

  alias Systemd.{DBus, Error}

  @destination "org.freedesktop.systemd1"
  @interface "org.freedesktop.DBus.Properties"

  @doc """
  Reads one property from a D-Bus object.
  """
  @spec get(pid(), String.t(), String.t(), String.t()) :: {:ok, term()} | {:error, Error.t()}
  def get(conn, object_path, interface, property) do
    with {:ok, [value]} <-
           DBus.call_body(conn,
             destination: @destination,
             path: object_path,
             interface: @interface,
             member: "Get",
             signature: "ss",
             body: [interface, property]
           ) do
      {:ok, unwrap_variant(value)}
    end
  end

  @doc """
  Reads every property for an interface from a D-Bus object.
  """
  @spec get_all(pid(), String.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get_all(conn, object_path, interface) do
    with {:ok, [properties]} <-
           DBus.call_body(conn,
             destination: @destination,
             path: object_path,
             interface: @interface,
             member: "GetAll",
             signature: "s",
             body: [interface]
           ) do
      {:ok, Map.new(properties, fn {name, value} -> {name, unwrap_variant(value)} end)}
    end
  end

  defp unwrap_variant({:variant, value}), do: value
  defp unwrap_variant({_signature, value}), do: value
  defp unwrap_variant(value), do: value
end
