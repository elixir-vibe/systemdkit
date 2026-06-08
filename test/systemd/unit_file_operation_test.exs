defmodule Systemd.UnitFileOperationTest do
  use ExUnit.Case, async: true

  alias Systemd.{UnitFileChange, UnitFileOperation}

  test "builds a consistent unit-file operation result" do
    operation =
      UnitFileOperation.new(
        [["symlink", "/etc/systemd/system/example.service", "/opt/example.service"]],
        carries_install_info: true
      )

    assert %UnitFileOperation{
             carries_install_info: true,
             changes: [
               %UnitFileChange{
                 action: :symlink,
                 path: "/etc/systemd/system/example.service",
                 target: "/opt/example.service"
               }
             ]
           } = operation
  end
end
