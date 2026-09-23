defmodule Frameshift.Library.Writer do
  @moduledoc """
  Runs durable mutations through the Library's single SQLite owner.

  A SQLite statement failure rolls back the transaction and becomes a returned
  error. Other exceptions still surface as programming faults. Every attempt
  emits the same bounded transaction metric after its outcome is known.
  """

  @doc "Runs one immediate transaction and reports its storage outcome."
  @spec transaction(pid(), (pid() -> term())) :: {:ok, term()} | {:error, term()}
  def transaction(connection, function) when is_function(function, 1) do
    started = System.monotonic_time(:millisecond)

    result =
      try do
        Exqlite.transaction(connection, function, mode: :immediate)
      rescue
        error in Exqlite.Error -> {:error, error}
      end

    :telemetry.execute(
      [:frameshift, :storage, :transaction],
      %{duration_ms: max(0, System.monotonic_time(:millisecond) - started)},
      %{outcome: if(match?({:ok, _}, result), do: :succeeded, else: :failed)}
    )

    result
  end

  @doc "Unwraps a completed mutation and maps SQLite errors to the public storage shape."
  @spec unwrap({:ok, term()} | {:error, term()}) :: term() | {:error, term()}
  def unwrap({:ok, reply}), do: reply
  def unwrap({:error, %Exqlite.Error{message: message}}), do: {:error, {:database, message}}
  def unwrap({:error, reason}), do: {:error, reason}
end
