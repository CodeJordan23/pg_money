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
    telemetry_prefix = Keyword.get(opts, :telemetry_prefix, [__MODULE__])

    %{
      precision: precision,
      telemetry_prefix: telemetry_prefix
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
  def encode(%{precision: p}) do
    quote location: :keep do
      %Decimal{} = decimal ->
        <<unquote(PgMoney.storage_size())::int32,
          unquote(__MODULE__).to_int(decimal, unquote(p))::int64>>

      n when is_float(n) ->
        <<unquote(PgMoney.storage_size())::int32,
          unquote(__MODULE__).to_int(Decimal.from_float(n), unquote(p))::int64>>

      n when is_integer(n) ->
        <<unquote(PgMoney.storage_size())::int32,
          unquote(__MODULE__).to_int(Decimal.new(n), unquote(p))::int64>>

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
    raise ArgumentError, "cannot represent #{inspect(other)} as money, not a valid int64."
  end

  @doc """
  Returns an integer which corresponds to `money` with given precision.
  """
  @spec to_int(Decimal.t(), PgMoney.precision()) :: integer
  def to_int(_decimal, precision) when not is_precision(precision) do
    raise ArgumentError, "invalid precision #{inspect(precision)}, must be a positive integer."
  end

  def to_int(%Decimal{coef: coef} = decimal, _) when coef in [:inf, :qNaN, :sNaN] do
    raise ArgumentError, "cannot represent #{inspect(decimal)} as money type."
  end

  def to_int(%Decimal{sign: sign, coef: coef, exp: e} = d, p) do
    case -e do
      n when p < n ->
        to_int(Decimal.round(d, p), p)

      n when n == p ->
        check_validity(sign * coef)

      n when n < p ->
        to_int(%Decimal{sign: sign, coef: trunc(coef * 10), exp: e - 1}, p)
    end
  end

  defp check_validity(int) when is_money(int) do
    int
  end

  defp check_validity(other) do
    raise ArgumentError, "invalid money value #{inspect(other)}"
  end
end
