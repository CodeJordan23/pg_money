defmodule PgMoney.Extension do
  @moduledoc """
  Implements how to encode and decode PostgeSQL's [`money` data type](https://www.postgresql.org/docs/9.5/datatype-money.html).
  """

  @behaviour Postgrex.Extension
  import PgMoney

  @impl true
  @spec init(keyword) :: PgMoney.config()
  def init(opts) do
    precision = Keyword.get(opts, :precision, 2)
    telemetry = Keyword.get(opts, :telemetry_prefix, [:pg_money])

    %{
      precision: precision,
      telemetry: telemetry
    }
  end

  @impl true
  @spec format(PgMoney.config()) :: :binary
  def format(_state), do: :binary

  @impl true
  @spec matching(PgMoney.config()) :: [receive: String.t(), send: String.t()]
  def matching(_state),
    do: [
      receive: "cash_recv",
      send: "cash_send"
    ]

  @impl true
  @spec decode(PgMoney.config()) :: Macro.t()
  def decode(%{precision: p, telemetry: t}) do
    quote location: :keep do
      <<unquote(PgMoney.storage_size())::int32,
        data::binary-size(unquote(PgMoney.storage_size()))>> ->
        <<digits::int64>> = data
        unquote(__MODULE__).to_dec(digits, unquote(p), unquote(t))
    end
  end

  @impl true
  @spec encode(PgMoney.config()) :: Macro.t()
  def encode(%{precision: p, telemetry: t}) do
    quote location: :keep do
      %Decimal{} = decimal ->
        <<unquote(PgMoney.storage_size())::int32,
          unquote(__MODULE__).to_int(decimal, unquote(p), unquote(t))::int64>>

      n when is_float(n) ->
        <<unquote(PgMoney.storage_size())::int32,
          unquote(__MODULE__).to_int(Decimal.from_float(n), unquote(p), unquote(t))::int64>>

      n when is_integer(n) ->
        <<unquote(PgMoney.storage_size())::int32,
          unquote(__MODULE__).to_int(Decimal.new(n), unquote(p), unquote(t))::int64>>

      other ->
        raise ArgumentError, "cannot encode #{inspect(other)} as money."
    end
  end

  @doc """
  Returns a `t:Decimal.t/0` which corresponds to `money` with given precision.
  """
  @spec to_dec(integer, PgMoney.precision(), PgMoney.telemetry()) :: Decimal.t()
  def to_dec(integer, precision \\ 2, telemetry \\ false)

  def to_dec(integer, precision, telemetry) do
    started_at = current_time()

    try do
      case {PgMoney.is_money(integer), PgMoney.is_precision(precision)} do
        {true, true} ->
          coef = abs(integer)

          %Decimal{
            sign:
              if coef == integer do
                1
              else
                -1
              end,
            coef: coef,
            exp: -precision
          }

        {false, false} ->
          raise ArgumentError,
                "invalid money (#{inspect(integer)}) and precision (#{inspect(precision)})"

        {false, _} ->
          raise ArgumentError,
                "cannot represent #{inspect(integer)} as `money`, not a valid int64."

        {_, false} ->
          raise ArgumentError,
                "invalid precision #{inspect(precision)}, must be a positive integer"
      end
    after
      duration = time_diff(started_at, current_time())
      emit_start(telemetry, :to_dec, started_at)
      emit_stop(telemetry, :to_dec, duration)
    end
  end

  @doc """
  Returns an integer which corresponds to `money` with given precision.
  """
  @spec to_int(Decimal.t(), PgMoney.precision(), PgMoney.telemetry()) :: integer
  def to_int(decimal, precision \\ 2, telemetry \\ false)

  def to_int(%Decimal{sign: sign, coef: coef, exp: e} = d, p, t) do
    started_at = current_time()

    try do
      cond do
        not is_precision(p) ->
          raise ArgumentError, "invalid precision #{inspect(p)}, must be a positive integer."

        coef in [:inf, :qNaN, :sNaN] ->
          raise ArgumentError, message: "cannot represent #{inspect(d)} as `money`."

        true ->
          {dst, int} =
            case e + p do
              n when n == 0 ->
                {d, sign * coef}

              n when 0 < n ->
                f = Enum.reduce(1..n, 1, fn _, acc -> 10 * acc end)
                {d, sign * coef * f}

              n when n < 0 ->
                dst = Decimal.round(d, p)
                {dst, dst.sign * dst.coef}
            end

          try do
            check_validity(int)
          after
            emit_event(t, :to_int, d, dst, p)
          end
      end
    after
      ended_at = current_time()
      duration = time_diff(started_at, ended_at)
      emit_start(t, :to_int, started_at)
      emit_stop(t, :to_int, duration)
    end
  end

  defp check_validity(int) when is_money(int) do
    int
  end

  defp check_validity(other) do
    raise ArgumentError, "invalid money value #{inspect(other)}"
  end

  defp emit_start(false, _op, _started_at), do: :ok

  defp emit_start(prefix, op, started_at) do
    name = prefix ++ [:start]

    :telemetry.execute(
      name,
      %{time: started_at},
      %{operation: op}
    )
  end

  defp emit_stop(false, _op, _duration), do: :ok

  defp emit_stop(prefix, op, duration) do
    name = prefix ++ [:stop]

    :telemetry.execute(
      name,
      %{duration: duration},
      %{operation: op}
    )
  end

  defp emit_event(false, _op, _src, _dst, _p), do: :ok

  defp emit_event(prefix, :to_int, %Decimal{} = src, %Decimal{} = dst, p) when is_list(prefix) do
    event =
      if Decimal.eq?(src, dst) do
        :lossless
      else
        :lossy
      end

    name = prefix ++ [event]

    :telemetry.execute(
      name,
      %{
        dst: dst,
        diff: Decimal.sub(src, dst)
      },
      %{
        src: src,
        precision: p
      }
    )
  end

  defp current_time, do: :erlang.monotonic_time(:nanosecond)
  defp time_diff(start, stop), do: stop - start
end
