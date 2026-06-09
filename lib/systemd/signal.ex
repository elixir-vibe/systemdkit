defmodule Systemd.Signal do
  @moduledoc """
  Helpers for receiving systemd D-Bus signals.
  """

  alias Rebus.Message
  alias Systemd.{DBus, Error}

  @dbus_destination "org.freedesktop.DBus"
  @dbus_path "/org/freedesktop/DBus"
  @dbus_interface "org.freedesktop.DBus"
  @systemd_destination "org.freedesktop.systemd1"
  @manager_path "/org/freedesktop/systemd1"
  @manager_interface "org.freedesktop.systemd1.Manager"

  @type subscription :: %__MODULE__{conn: pid(), ref: reference(), match_rule: String.t()}
  @type job_removed :: %{
          id: non_neg_integer(),
          job_path: String.t(),
          unit: String.t(),
          result: String.t()
        }

  @enforce_keys [:conn, :ref, :match_rule]
  defstruct [:conn, :ref, :match_rule]

  @doc """
  Subscribes the current process to systemd manager signals.
  """
  @spec subscribe_manager(pid()) :: {:ok, subscription()} | {:error, Error.t()}
  def subscribe_manager(conn) when is_pid(conn) do
    match_rule =
      "type='signal',sender='#{@systemd_destination}',path='#{@manager_path}',interface='#{@manager_interface}'"

    with :ok <- add_match(conn, match_rule),
         {:ok, []} <- manager_call(conn, "Subscribe"),
         ref when is_reference(ref) <- Rebus.add_signal_handler(conn) do
      {:ok, %__MODULE__{conn: conn, ref: ref, match_rule: match_rule}}
    else
      {:error, %Error{} = error} -> {:error, error}
      other -> {:error, Error.protocol_error(other)}
    end
  end

  @doc """
  Removes a signal subscription returned by `subscribe_manager/1`.
  """
  @spec unsubscribe(subscription()) :: :ok | {:error, Error.t()}
  def unsubscribe(%__MODULE__{conn: conn, ref: ref, match_rule: match_rule}) do
    :ok = Rebus.delete_signal_handler(conn, ref)
    remove_match(conn, match_rule)
  end

  @doc """
  Waits for a `JobRemoved` signal matching a job object path.
  """
  @spec await_job_removed(subscription(), String.t(), keyword()) ::
          {:ok, job_removed()} | {:error, Error.t()}
  def await_job_removed(%__MODULE__{ref: ref}, job_path, opts \\ []) when is_binary(job_path) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    deadline = System.monotonic_time(:millisecond) + timeout
    do_await_job_removed(ref, job_path, deadline)
  end

  defp do_await_job_removed(ref, job_path, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {^ref, %Message{} = message} ->
        case job_removed(message) do
          {:ok, %{job_path: ^job_path} = removed} -> {:ok, removed}
          {:ok, _other_job} -> do_await_job_removed(ref, job_path, deadline)
          :ignore -> do_await_job_removed(ref, job_path, deadline)
        end
    after
      remaining -> {:error, Error.connection_error(:timeout)}
    end
  end

  defp job_removed(%Message{
         type: :signal,
         header_fields: headers,
         body: [id, job_path, unit, result]
       }) do
    if Map.get(headers, :member) == "JobRemoved" and
         Map.get(headers, :interface) == @manager_interface do
      {:ok, %{id: id, job_path: job_path, unit: unit, result: result}}
    else
      :ignore
    end
  end

  defp job_removed(_message), do: :ignore

  defp add_match(conn, match_rule), do: dbus_void_call(conn, "AddMatch", [match_rule], "s")
  defp remove_match(conn, match_rule), do: dbus_void_call(conn, "RemoveMatch", [match_rule], "s")

  defp manager_call(conn, member) do
    DBus.call_body(conn,
      destination: @systemd_destination,
      path: @manager_path,
      interface: @manager_interface,
      member: member
    )
  end

  defp dbus_void_call(conn, member, body, signature) do
    with {:ok, []} <-
           DBus.call_body(conn,
             destination: @dbus_destination,
             path: @dbus_path,
             interface: @dbus_interface,
             member: member,
             signature: signature,
             body: body
           ) do
      :ok
    end
  end
end
