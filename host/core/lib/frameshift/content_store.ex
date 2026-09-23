defmodule Frameshift.ContentStore do
  @moduledoc """
  Stores immutable content-addressed bytes outside the metadata database.

  Writes use a bounded work area and verified digest placement. Recovery keeps
  protected and recently removed objects available rather than silently
  deleting them after an interrupted filesystem move.
  """

  alias Frameshift.Digest

  @type placement :: :existing | :created | :restored

  @spec prepare(String.t()) :: :ok | {:error, File.posix()}
  def prepare(data_dir) do
    directories = [
      data_dir | Enum.map(~w(objects objects/sha256 work trash), &Path.join(data_dir, &1))
    ]

    Enum.reduce_while(directories, :ok, fn path, :ok ->
      with :ok <- File.mkdir_p(path),
           :ok <- File.chmod(path, 0o700) do
        {:cont, :ok}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @spec put(String.t(), iodata()) ::
          {:ok, String.t(), non_neg_integer(), placement()} | {:error, term()}
  def put(data_dir, bytes) do
    binary = IO.iodata_to_binary(bytes)
    digest = Digest.sha256(binary)
    destination = object_path(data_dir, digest)

    with :ok <- File.mkdir_p(Path.dirname(destination)) do
      cond do
        File.regular?(destination) ->
          verify_existing(destination, digest, byte_size(binary), :existing)

        File.regular?(trash_path(data_dir, digest)) ->
          restore_from_trash(data_dir, digest, byte_size(binary))

        true ->
          write_new(data_dir, destination, digest, binary)
      end
    end
  end

  @spec read(String.t(), String.t(), pos_integer()) :: {:ok, binary()} | {:error, term()}
  def read(data_dir, digest, maximum_bytes)
      when is_binary(data_dir) and is_binary(digest) and is_integer(maximum_bytes) and
             maximum_bytes > 0 do
    with true <- Digest.valid_sha256?(digest),
         {:ok, file} <- File.open(object_path(data_dir, digest), [:read, :binary]) do
      try do
        read_open_file(file, digest, maximum_bytes)
      after
        File.close(file)
      end
    else
      false -> {:error, :invalid_digest}
      {:error, reason} -> {:error, reason}
    end
  end

  def read(_data_dir, _digest, _maximum_bytes), do: {:error, :invalid_read}

  @spec move_to_trash(String.t(), String.t()) :: :ok | {:error, term()}
  def move_to_trash(data_dir, digest) do
    source = object_path(data_dir, digest)
    destination = trash_path(data_dir, digest)

    cond do
      File.regular?(destination) -> :ok
      not File.exists?(source) -> {:error, :object_missing}
      true -> File.rename(source, destination)
    end
  end

  @spec restore(String.t(), String.t()) :: :ok | {:error, term()}
  def restore(data_dir, digest) do
    source = trash_path(data_dir, digest)
    destination = object_path(data_dir, digest)

    cond do
      File.regular?(destination) ->
        :ok

      not File.exists?(source) ->
        {:error, :object_missing}

      true ->
        with :ok <- File.mkdir_p(Path.dirname(destination)),
             do: File.rename(source, destination)
    end
  end

  @spec delete_trashed(String.t(), String.t()) :: :ok | {:error, File.posix()}
  def delete_trashed(data_dir, digest), do: File.rm(trash_path(data_dir, digest))

  @spec delete_active(String.t(), String.t()) :: :ok | {:error, File.posix()}
  def delete_active(data_dir, digest), do: File.rm(object_path(data_dir, digest))

  @spec reconcile(String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def reconcile(data_dir, digest, storage_state) do
    object = object_path(data_dir, digest)
    trash = trash_path(data_dir, digest)

    case {storage_state, File.regular?(object), File.regular?(trash)} do
      {"active", true, _trash_present} -> :ok
      {"active", false, true} -> restore(data_dir, digest)
      {"trash", _object_present, true} -> :ok
      {"trash", true, false} -> move_to_trash(data_dir, digest)
      {_state, false, false} -> {:error, {:object_missing, digest}}
    end
  end

  @spec object_path(String.t(), String.t()) :: String.t()
  def object_path(data_dir, digest) do
    hex = Digest.hex!(digest)
    Path.join([data_dir, "objects", "sha256", binary_part(hex, 0, 2), binary_part(hex, 2, 62)])
  end

  @spec trash_path(String.t(), String.t()) :: String.t()
  def trash_path(data_dir, digest) do
    Path.join([data_dir, "trash", Digest.hex!(digest)])
  end

  defp write_new(data_dir, destination, digest, binary) do
    temporary =
      Path.join([
        data_dir,
        "work",
        "#{Digest.hex!(digest)}-#{System.unique_integer([:positive])}"
      ])

    result =
      with :ok <- write_synced(temporary, binary),
           :ok <- publish(temporary, destination),
           {:ok, ^digest, size, :created} <-
             verify_existing(destination, digest, byte_size(binary), :created) do
        {:ok, digest, size, :created}
      end

    if match?({:error, _}, result), do: File.rm(temporary)
    result
  end

  defp write_synced(path, binary) do
    case File.open(path, [:write, :binary, :exclusive]) do
      {:ok, file} ->
        try do
          with :ok <- IO.binwrite(file, binary),
               do: :file.sync(file)
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp publish(temporary, destination) do
    case File.rename(temporary, destination) do
      :ok -> :ok
      {:error, :eexist} -> File.rm(temporary)
      {:error, reason} -> {:error, reason}
    end
  end

  defp restore_from_trash(data_dir, digest, expected_size) do
    with :ok <- restore(data_dir, digest),
         {:ok, ^digest, size, :restored} <-
           verify_existing(object_path(data_dir, digest), digest, expected_size, :restored) do
      {:ok, digest, size, :restored}
    end
  end

  defp verify_existing(path, digest, expected_size, placement) do
    with {:ok, stat} <- File.stat(path),
         true <- stat.size == expected_size,
         {:ok, actual} <- hash_file(path),
         true <- actual == digest do
      {:ok, digest, stat.size, placement}
    else
      false -> {:error, :content_address_collision}
      {:error, reason} -> {:error, reason}
    end
  end

  defp hash_file(path) do
    with {:ok, file} <- File.open(path, [:read, :binary]) do
      digest = hash_stream(file, :crypto.hash_init(:sha256))
      File.close(file)
      digest
    end
  end

  defp read_open_file(file, digest, maximum_bytes) do
    with {:ok, info} <- :file.read_file_info(file),
         stat = File.Stat.from_record(info),
         :ok <- validate_read_stat(stat, maximum_bytes),
         bytes when is_binary(bytes) <- IO.binread(file, stat.size + 1),
         true <- byte_size(bytes) == stat.size,
         true <- Digest.sha256(bytes) == digest do
      {:ok, bytes}
    else
      :eof -> {:error, :object_changed}
      false -> {:error, :content_address_mismatch}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_read_stat(%File.Stat{type: :regular, size: size}, maximum_bytes)
       when size <= maximum_bytes,
       do: :ok

  defp validate_read_stat(%File.Stat{type: :regular}, _maximum_bytes),
    do: {:error, :object_too_large}

  defp validate_read_stat(%File.Stat{}, _maximum_bytes), do: {:error, :object_not_regular}

  defp hash_stream(file, context) do
    case IO.binread(file, 64 * 1024) do
      :eof ->
        {:ok, "sha256:" <> (:crypto.hash_final(context) |> Base.encode16(case: :lower))}

      {:error, reason} ->
        {:error, reason}

      bytes ->
        hash_stream(file, :crypto.hash_update(context, bytes))
    end
  end
end
