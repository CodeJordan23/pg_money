defmodule PgMoney.Extension do
  @moduledoc """
  Implements how to encode and decode PostgeSQL's [`money` data type](https://www.postgresql.org/docs/9.5/datatype-money.html).
  """

  @behaviour Postgrex.Extension
  import Postgrex.BinaryUtils

  @min_int_val -9_223_372_036_854_775_808
  @max_int_val +9_223_372_036_854_775_807
  @storage_size 8

  @doc """
  The minimum integer value possible for the `money` type.
  """
  @spec min_int_val :: neg_integer()
  def min_int_val, do: @min_int_val

  @doc """
  The maximum integer value possible for the `money` type.
  """
  @spec max_int_val :: pos_integer()
  def max_int_val, do: @max_int_val

  @doc """
  Defines the storage size the `money` data type takes up in the database.
  """
  @spec storage_size :: non_neg_integer()
  def storage_size, do: @storage_size

  @impl true
  def init(opts) do
    %{precision: Keyword.get(opts, :precision, 2)}
  end

  @impl true
  def format(_state), do: :binary

  @impl true
  def matching(_state),
    do: [
      receive: "cash_recv",
      send: "cash_send"
    ]

  @impl true
  def decode(%{precision: p}) do
    quote location: :keep do
      <<unquote(@storage_size)::int32, data::binary-size(unquote(@storage_size))>> ->
        <<digits::int64>> = data
        unquote(__MODULE__).to_dec(digits, unquote(p))
    end
  end

  @doc """
  Returns a `t:Decimal.t/0` which corresponds to `money` with given precision.
  """
  @spec to_dec(integer, non_neg_integer()) :: Decimal.t()
  def to_dec(_integer, precision) when not is_integer(precision) or precision < 0 do
    raise ArgumentError, "invalid precision #{inspect(precision)}, must be a positive integer"
  end

  def to_dec(integer, p) when is_integer(integer) and is_integer(p) do
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

  @impl true
  def encode(%{precision: p}) do
    quote location: :keep do
      %Decimal{} = decimal ->
        <<unquote(@storage_size)::int32, unquote(__MODULE__).to_int(decimal, unquote(p))::int64>>

      n when is_float(n) ->
        <<unquote(@storage_size)::int32,
          unquote(__MODULE__).to_int(Decimal.from_float(n), unquote(p))::int64>>

      n when is_integer(n) ->
        <<unquote(@storage_size)::int32,
          unquote(__MODULE__).to_int(Decimal.new(n), unquote(p))::int64>>

      other ->
        raise ArgumentError, "cannot encode #{inspect(other)} as money."
    end
  end

  @doc """
  Returns an integer which corresponds to `money` with given precision.
  """
  @spec to_int(Decimal.t(), non_neg_integer()) :: integer
  def to_int(_decimal, precision) when not is_integer(precision) or precision < 0 do
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

  defp check_validity(int) when int < @min_int_val do
    raise ArgumentError, "#{inspect(int)} exceeds money's min value #{inspect(@min_int_val)}"
  end

  defp check_validity(int) when @max_int_val < int do
    raise ArgumentError, "#{inspect(int)} exceeds money's max value #{inspect(@max_int_val)}"
  end

  defp check_validity(int) when is_integer(int) do
    int
  end
end
