defmodule Systemd.DBus.Signature do
  @moduledoc false

  @supported_complex_signatures MapSet.new([
                                  "a(ssssssouso)",
                                  "a(ss)",
                                  "a{sv}",
                                  "a(sv)",
                                  "a(sa(sv))",
                                  "ssa(sv)a(sa(sv))"
                                ])

  @doc false
  @spec supported?(String.t()) :: boolean()
  def supported?(signature) when is_binary(signature) do
    primitive?(signature) or MapSet.member?(@supported_complex_signatures, signature)
  end

  defp primitive?(""), do: true

  defp primitive?(signature) do
    signature
    |> String.to_charlist()
    |> Enum.all?(&(&1 in ~c"syobintqxuagdvh"))
  end
end
