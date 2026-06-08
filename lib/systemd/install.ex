defmodule Systemd.Install do
  @moduledoc """
  Helpers for installing generated unit files.

  File writes are intentionally local filesystem operations. Reloading systemd is
  still performed through the D-Bus manager API, not through `systemctl`.
  """

  alias Systemd.{Error, Manager, UnitFile}

  @system_unit_dir "/etc/systemd/system"
  @user_unit_dir Path.join(System.user_home!(), ".config/systemd/user")

  @type target :: :system | :user | {:directory, Path.t()}

  @doc """
  Returns the target path for a unit name.
  """
  @spec unit_path(String.t(), target()) :: Path.t()
  def unit_path(name, target \\ :system)
  def unit_path(name, :system), do: Path.join(@system_unit_dir, name)
  def unit_path(name, :user), do: Path.join(@user_unit_dir, name)
  def unit_path(name, {:directory, directory}), do: Path.join(directory, name)

  @doc """
  Writes a unit file to the selected target directory.
  """
  @spec write_unit(String.t(), UnitFile.t() | String.t(), keyword()) ::
          {:ok, Path.t()} | {:error, Error.t()}
  def write_unit(name, unit_file_or_text, opts \\ []) do
    target = Keyword.get(opts, :target, :system)
    path = unit_path(name, target)
    text = render(unit_file_or_text)

    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, text) do
      {:ok, path}
    else
      {:error, reason} -> {:error, Error.connection_error(reason)}
    end
  end

  @doc """
  Writes a unit file and reloads systemd manager configuration over D-Bus.
  """
  @spec install_unit(String.t(), UnitFile.t() | String.t(), keyword()) ::
          {:ok, Path.t()} | {:error, Error.t()}
  def install_unit(name, unit_file_or_text, opts \\ []) do
    with {:ok, path} <- write_unit(name, unit_file_or_text, opts),
         {:ok, conn} <- Manager.connect(bus: Keyword.get(opts, :bus, :system)),
         :ok <- Manager.reload(conn) do
      {:ok, path}
    end
  end

  defp render(%UnitFile{} = unit_file), do: UnitFile.to_string(unit_file)
  defp render(text) when is_binary(text), do: text
end
