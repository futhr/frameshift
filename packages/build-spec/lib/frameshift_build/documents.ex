defmodule FrameshiftBuild.Documents do
  @moduledoc false

  @spec input_types(term()) :: :ok | {:error, binary()}
  def input_types(documents) when length(documents) <= 64 do
    if Enum.all?(documents, &is_binary/1), do: :ok, else: {:error, "invalid_document"}
  end

  def input_types(documents) when length(documents) > 64, do: {:error, "invalid_count"}
  def input_types(_), do: {:error, "invalid_document"}

  @spec hash([binary()], (binary() -> {:ok, binary()} | {:error, binary()})) ::
          {:ok, [{binary(), binary()}]} | {:error, binary()}
  def hash(documents, identity) do
    Enum.reduce_while(documents, {:ok, []}, fn bytes, {:ok, acc} ->
      case identity.(bytes) do
        {:ok, pin} -> {:cont, {:ok, [{pin, bytes} | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  @spec normalize({:ok, term()} | {:error, term()}) :: {:ok, term()} | {:error, binary()}
  def normalize({:ok, value}), do: {:ok, value}
  def normalize({:error, error}), do: {:error, :frameshift_build.refusal_code(error)}
end
