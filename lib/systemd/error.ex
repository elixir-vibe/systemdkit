defmodule Systemd.Error do
  @moduledoc """
  Structured error returned by systemd and D-Bus operations.
  """

  @type source :: :dbus | :connection | :protocol | :validation
  @type category :: :permission | :not_found | :timeout | :invalid | :unsupported | :unknown

  @type t :: %__MODULE__{
          source: source(),
          reason: atom(),
          category: category(),
          message: String.t(),
          dbus_name: String.t() | nil,
          body: [term()],
          details: term()
        }

  defexception [:source, :reason, :message, :dbus_name, :category, body: [], details: nil]

  @doc false
  @spec dbus_error(String.t() | nil, [term()]) :: t()
  def dbus_error(name, body) when is_list(body) do
    %__MODULE__{
      source: :dbus,
      reason: reason_from_dbus_name(name),
      category: category_from_reason(reason_from_dbus_name(name)),
      message: message_from_body(body, name),
      dbus_name: name,
      body: body
    }
  end

  @doc false
  @spec connection_error(term()) :: t()
  def connection_error(reason) do
    %__MODULE__{
      source: :connection,
      reason: normalize_reason(reason),
      category: category_from_reason(normalize_reason(reason)),
      message: "D-Bus connection failed: #{inspect(reason)}",
      details: reason
    }
  end

  @doc false
  @spec encoding_error(term()) :: t()
  def encoding_error(details) do
    %__MODULE__{
      source: :protocol,
      reason: :unsupported_type,
      category: :unsupported,
      message: "Unsupported D-Bus value or signature: #{inspect(details)}",
      details: details
    }
  end

  @doc false
  @spec protocol_error(term()) :: t()
  def protocol_error(details) do
    %__MODULE__{
      source: :protocol,
      reason: :unexpected_reply,
      category: :unsupported,
      message: "Unexpected D-Bus reply: #{inspect(details)}",
      details: details
    }
  end

  @doc false
  @spec validation_error(term()) :: t()
  def validation_error(reason) do
    %__MODULE__{
      source: :validation,
      reason: :invalid_call,
      category: :invalid,
      message: "Invalid D-Bus call: #{inspect(reason)}",
      details: reason
    }
  end

  defp message_from_body([message | _], _name) when is_binary(message), do: message
  defp message_from_body(_body, name) when is_binary(name), do: name
  defp message_from_body(_body, _name), do: "D-Bus method call failed"

  @doc """
  Returns true when the error is a systemd/D-Bus permission or polkit denial.
  """
  @spec permission?(t()) :: boolean()
  def permission?(%__MODULE__{category: :permission}), do: true
  def permission?(_error), do: false

  defp reason_from_dbus_name("org.freedesktop.DBus.Error.AccessDenied"), do: :access_denied
  defp reason_from_dbus_name("org.freedesktop.DBus.Error.AuthFailed"), do: :auth_failed
  defp reason_from_dbus_name("org.freedesktop.DBus.Error.FileNotFound"), do: :file_not_found

  defp reason_from_dbus_name("org.freedesktop.DBus.Error.InteractiveAuthorizationRequired"),
    do: :interactive_authorization_required

  defp reason_from_dbus_name("org.freedesktop.DBus.Error.InvalidArgs"), do: :invalid_args
  defp reason_from_dbus_name("org.freedesktop.DBus.Error.NoReply"), do: :no_reply
  defp reason_from_dbus_name("org.freedesktop.DBus.Error.ServiceUnknown"), do: :service_unknown
  defp reason_from_dbus_name("org.freedesktop.DBus.Error.UnknownMethod"), do: :unknown_method
  defp reason_from_dbus_name("org.freedesktop.DBus.Error.UnknownObject"), do: :unknown_object
  defp reason_from_dbus_name("org.freedesktop.systemd1.NoSuchJob"), do: :no_such_job
  defp reason_from_dbus_name("org.freedesktop.systemd1.NoSuchUnit"), do: :no_such_unit
  defp reason_from_dbus_name("org.freedesktop.systemd1.UnitExists"), do: :unit_exists
  defp reason_from_dbus_name(_name), do: :dbus_error

  defp category_from_reason(reason)
       when reason in [:access_denied, :auth_failed, :interactive_authorization_required],
       do: :permission

  defp category_from_reason(reason)
       when reason in [
              :file_not_found,
              :no_such_job,
              :no_such_unit,
              :service_unknown,
              :unknown_object
            ],
       do: :not_found

  defp category_from_reason(reason) when reason in [:invalid_args, :invalid_call], do: :invalid
  defp category_from_reason(reason) when reason in [:no_reply, :timeout], do: :timeout

  defp category_from_reason(reason) when reason in [:unexpected_reply, :unsupported_type],
    do: :unsupported

  defp category_from_reason(_reason), do: :unknown

  defp normalize_reason(reason) when is_atom(reason), do: reason
  defp normalize_reason({reason, _}) when is_atom(reason), do: reason
  defp normalize_reason(_reason), do: :error
end
