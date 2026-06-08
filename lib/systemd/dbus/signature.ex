defmodule Systemd.DBus.Signature do
  @moduledoc false

  @supported_complex_signatures MapSet.new([
                                  "a(ssssssouso)",
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
    String.match?(signature, ~r/^[syobintqxuagdvh]+$/)
  end
end
