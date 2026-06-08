defmodule Systemd.InstallTest do
  use ExUnit.Case, async: true

  alias Systemd.{Install, UnitFile}

  test "writes unit files to explicit directories" do
    directory =
      Path.join(System.tmp_dir!(), "systemd-install-test-#{System.unique_integer([:positive])}")

    unit_file = UnitFile.service(service: [exec_start: "/bin/true"])

    assert {:ok, path} =
             Install.write_unit("example.service", unit_file, target: {:directory, directory})

    assert path == Path.join(directory, "example.service")
    assert File.read!(path) == "[Service]\nExecStart=/bin/true\n"

    File.rm_rf!(directory)
  end
end
