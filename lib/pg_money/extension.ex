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
  Defines the minimum integer value possible for the `money` type.
  """
  def min_int_val, do: @min_int_val

  @doc """
  Defines the maximum integer value possible for the `money` type.
  """
  def max_int_val, do: @max_int_val

  @doc """
  Defines the size in the database.
  """
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
        unquote(__MODULE__).to_decimal(digits, unquote(p))
    end
  end

  def to_decimal(_, p) when not(is_integer(p)) or p < 0 do
    raise ArgumentError, "invalid precision #{inspect(p)}, must be a positive integer"
  end
  def to_decimal(digits, _p) when is_integer(digits) do
    Decimal.div(Decimal.new(digits), Decimal.new(100))
  end
  def to_decimal(other, _p) do
    raise ArgumentError, "cannot represent #{inspect(other)} as money, not a valid int64."
  end


  @impl true
  def encode(%{precision: p}) do
    quote location: :keep do
      %Decimal{} = decimal ->
        <<unquote(@storage_size)::int32, (unquote(__MODULE__).to_binary(decimal, unquote(p)))::int64>>
      n when is_float(n) ->
        <<unquote(@storage_size)::int32, (unquote(__MODULE__).to_binary(Decimal.from_float(n), unquote(p)))::int64>>
      n when is_integer(n) ->
        <<unquote(@storage_size)::int32, (unquote(__MODULE__).to_binary(Decimal.new(n), unquote(p)))::int64>>
      other -> raise ArgumentError, "cannot encode #{inspect(other)} as money."
    end
  end

  def to_binary(_, p) when not(is_integer(p)) or p < 0 do
    raise ArgumentError, "invalid precision #{inspect(p)}, must be a positive integer."
  end
  def to_binary(%Decimal{coef: coef} = decimal, _) when coef in [:inf, :qNaN, :sNaN] do
    raise ArgumentError, "cannot represent #{inspect(decimal)} as money type."
  end
  def to_binary(%Decimal{sign: sign, coef: coef, exp: e} = d, p) do
    case e do
      0 -> check_validity(sign * coef * 100)
      -1 -> check_validity(sign * coef * 10)
      -2 -> check_validity(sign * coef)
      _ -> to_binary(Decimal.round(d, 2), p)
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
