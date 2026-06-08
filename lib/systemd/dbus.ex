defmodule Systemd.DBus do
  @moduledoc """
  Small D-Bus client wrapper used by the systemd API.

  This module intentionally keeps the surface tiny: connect to a bus and perform
  method calls, returning structured results or structured errors.
  """

  alias Rebus.Connection
  alias Rebus.Message
  alias Systemd.DBus.Result
  alias Systemd.Error

  @type bus ::
          :system | :session | %{required(:family) => :local | :inet, optional(atom()) => term()}
  @type call_option ::
          {:destination, String.t()}
          | {:path, String.t()}
          | {:interface, String.t()}
          | {:member, String.t()}
          | {:signature, String.t()}
          | {:body, [term()]}

  @doc """
  Connects to a D-Bus bus.

  Defaults to the system bus because systemd exposes its manager API there.
  """
  @spec connect(bus(), keyword()) :: {:ok, pid()} | {:error, Error.t()}
  def connect(bus \\ :system, opts \\ []) do
    with {:ok, _apps} <- Application.ensure_all_started(:rebus),
         {:ok, conn} <- Rebus.connect(bus, opts) do
      {:ok, conn}
    else
      {:error, %Error{} = error} -> {:error, error}
      {:error, reason} -> {:error, Error.connection_error(reason)}
    end
  end

  @doc """
  Sends a method call and returns a structured D-Bus result.
  """
  @spec call(pid(), [call_option()]) :: {:ok, Result.t()} | {:error, Error.t()}
  def call(conn, opts) when is_pid(conn) and is_list(opts) do
    with {:ok, message} <- message(opts) do
      send_message(conn, message)
    end
  end

  @doc """
  Sends a method call and returns only the decoded D-Bus body.
  """
  @spec call_body(pid(), [call_option()]) :: {:ok, [term()]} | {:error, Error.t()}
  def call_body(conn, opts) do
    with {:ok, %Result{body: body}} <- call(conn, opts), do: {:ok, body}
  end

  defp message(opts) do
    Message.new(:method_call,
      destination: Keyword.fetch!(opts, :destination),
      path: Keyword.fetch!(opts, :path),
      interface: Keyword.fetch!(opts, :interface),
      member: Keyword.fetch!(opts, :member),
      signature: Keyword.get(opts, :signature, ""),
      body: Keyword.get(opts, :body, [])
    )
  rescue
    error in KeyError -> {:error, Error.validation_error(error)}
  end

  defp send_message(conn, message) do
    conn
    |> Connection.send(message)
    |> to_result()
  catch
    :exit, reason -> {:error, Error.connection_error(reason)}
  end

  defp to_result(%Message{type: :method_return, body: body} = message) do
    {:ok, %Result{message: message, body: body}}
  end

  defp to_result(%Message{type: :error, header_fields: header_fields, body: body}) do
    {:error, Error.dbus_error(Map.get(header_fields, :error_name), body)}
  end

  defp to_result({:error, reason}), do: {:error, Error.connection_error(reason)}
  defp to_result(other), do: {:error, Error.protocol_error(other)}
end
