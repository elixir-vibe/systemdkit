defmodule Systemd.DBus do
  @moduledoc """
  Small D-Bus client wrapper used by the systemd API.

  This module intentionally keeps the surface tiny: connect to a bus and perform
  method calls, returning decoded D-Bus bodies or structured D-Bus errors.
  """

  alias Rebus.Connection
  alias Rebus.Message
  alias Systemd.DBus.Error

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
  @spec connect(bus(), keyword()) :: {:ok, pid()} | {:error, term()}
  def connect(bus \\ :system, opts \\ []) do
    with {:ok, _apps} <- Application.ensure_all_started(:rebus) do
      Rebus.connect(bus, opts)
    end
  end

  @doc """
  Sends a method call and returns the decoded D-Bus body.
  """
  @spec call(pid(), [call_option()]) :: {:ok, [term()]} | {:error, Error.t() | term()}
  def call(conn, opts) when is_pid(conn) and is_list(opts) do
    with {:ok, message} <- message(opts) do
      case Connection.send(conn, message) do
        %Message{type: :method_return, body: body} ->
          {:ok, body}

        %Message{type: :error, header_fields: header_fields, body: body} ->
          {:error,
           %Error{
             name: Map.get(header_fields, :error_name),
             message: error_message(body),
             body: body
           }}

        {:error, reason} ->
          {:error, reason}

        other ->
          {:error, {:unexpected_reply, other}}
      end
    end
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
  end

  defp error_message([message | _]) when is_binary(message), do: message
  defp error_message(_body), do: nil
end
