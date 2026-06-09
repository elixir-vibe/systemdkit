defmodule Systemd.DBus.SignatureTest do
  use ExUnit.Case, async: true

  alias Systemd.DBus.Signature

  test "documents signatures this package intentionally uses" do
    assert Signature.supported?("")
    assert Signature.supported?("asbb")
    assert Signature.supported?("a(ss)")
    assert Signature.supported?("a(usssoo)")
    assert Signature.supported?("ssa(sv)a(sa(sv))")
    refute Signature.supported?("a{sa{sv}}")
  end
end
