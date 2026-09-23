defmodule Frameshift.LocalIPC.PeerIdentity do
  @moduledoc """
  Reads the kernel-reported effective user ID of a connected local socket.

  Darwin uses `LOCAL_PEERCRED` (`struct xucred`). Linux uses `SO_PEERCRED`.
  Unsupported systems fail closed. The numeric constants come from each OS's
  socket headers and are covered by platform contract tests.
  """

  @doc "Returns the peer's effective UID or an error."
  @spec uid(:socket.socket()) :: {:ok, non_neg_integer()} | {:error, term()}
  def uid(socket) do
    case :os.type() do
      {:unix, :darwin} -> darwin_uid(socket)
      {:unix, :linux} -> linux_uid(socket)
      _unsupported -> {:error, :unsupported_peer_identity}
    end
  end

  defp darwin_uid(socket) do
    case :socket.getopt_native(socket, {0, 1}, 80) do
      {:ok,
       <<0::native-unsigned-integer-size(32), uid::native-unsigned-integer-size(32),
         _rest::binary>>} ->
        {:ok, uid}

      {:ok, _invalid} ->
        {:error, :invalid_peer_credential}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp linux_uid(socket) do
    case :socket.getopt(socket, :socket, :peercred) do
      {:ok, %{uid: uid}} when is_integer(uid) and uid >= 0 ->
        {:ok, uid}

      _other ->
        case :socket.getopt_native(socket, {1, 17}, 12) do
          {:ok,
           <<_pid::native-signed-integer-size(32), uid::native-unsigned-integer-size(32),
             _gid::native-unsigned-integer-size(32)>>} ->
            {:ok, uid}

          {:ok, _invalid} ->
            {:error, :invalid_peer_credential}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end
end
