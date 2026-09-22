defmodule Frameshift.LocalIPC.Token do
  @moduledoc false

  @token_pattern ~r/^[0-9a-f]{64}$/

  @spec consume(String.t()) :: {:ok, String.t()} | {:error, atom() | File.posix()}
  def consume(path) when is_binary(path) and byte_size(path) in 1..1_024 do
    expanded = Path.expand(path)

    with {:ok, file} <- File.open(expanded, [:read, :binary]),
         result <- read_token(file),
         :ok <- File.close(file),
         :ok <- File.rm(expanded) do
      result
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def consume(_path), do: {:error, :invalid_token_path}

  defp read_token(file) do
    with {:ok, info} <- :file.read_file_info(file),
         stat = File.Stat.from_record(info),
         :ok <- validate_stat(stat),
         token when is_binary(token) <- IO.binread(file, 65),
         true <- Regex.match?(@token_pattern, token) do
      {:ok, token}
    else
      :eof -> {:error, :invalid_ipc_token}
      false -> {:error, :invalid_ipc_token}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_stat(%File.Stat{type: :regular, size: 64, mode: mode}) do
    if Bitwise.band(mode, 0o077) == 0,
      do: :ok,
      else: {:error, :unsafe_token_permissions}
  end

  defp validate_stat(%File.Stat{type: :regular}), do: {:error, :invalid_ipc_token}
  defp validate_stat(%File.Stat{}), do: {:error, :invalid_token_file}
end
