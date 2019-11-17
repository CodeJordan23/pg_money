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
  def decode(%{precision: p}) do
    quote location: :keep do
      <<unquote(PgMoney.storage_size())::int32,
        data::binary-size(unquote(PgMoney.storage_size()))>> ->
        <<digits::int64>> = data
        unquote(__MODULE__).to_dec(digits, unquote(p))
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
  @spec to_dec(integer, non_neg_integer()) :: Decimal.t()
  def to_dec(_integer, precision) when not is_integer(precision) or precision < 0 do
    raise ArgumentError, "invalid precision #{inspect(precision)}, must be a positive integer"
  end

  def to_dec(integer, p) when PgMoney.is_money(integer) and PgMoney.is_precision(p) do
    coef = abs(integer)

    %Decimal{
      sign:
        if coef == integer do
          1
        else
          -1
        end,
      coef: coef,
      exp: -p
    }
  end

  def to_dec(other, _p) do
    raise ArgumentError, "cannot represent #{inspect(other)} as `money`, not a valid int64."
  end

  @doc """
  Returns an integer which corresponds to `money` with given precision.
  """
  @spec to_int(Decimal.t(), PgMoney.precision(), PgMoney.telemetry()) :: integer
  def to_int(decimal, precision, telemetry \\ false)

  def to_int(_, p, _) when not is_precision(p) do
    raise ArgumentError, "invalid precision #{inspect(p)}, must be a positive integer."
  end

  def to_int(%Decimal{coef: coef} = d, _, _) when coef in [:inf, :qNaN, :sNaN] do
    raise ArgumentError, "cannot represent #{inspect(d)} as `money`."
  end

  def to_int(%Decimal{sign: sign, coef: coef, exp: e} = d, p, t) do
    case e + p do
      n when n == 0 ->
        emit_event(t, d, d, p)
        check_validity(sign * coef)

      n when 0 < n ->
        emit_event(t, d, d, p)
        f = Enum.reduce(1..n, 1, fn _, acc -> 10 * acc end)
        check_validity(sign * coef * f)

      n when n < 0 ->
        dst = Decimal.round(d, p)
        emit_event(t, d, dst, p)
        check_validity(dst.sign * dst.coef)
    end
  end

  defp check_validity(int) when is_money(int) do
    int
  end

  defp check_validity(other) do
    raise ArgumentError, "invalid money value #{inspect(other)}"
  end

  defp emit_event(false, _src, _dst, _p), do: :ok

  defp emit_event(prefix, %Decimal{} = src, %Decimal{} = dst, p) when is_list(prefix) do
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
end
