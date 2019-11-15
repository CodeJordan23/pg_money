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
  def init(_opts) do
    nil
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
  def decode(_state) do
    quote location: :keep do
      <<unquote(@storage_size)::int32, data::binary-size(unquote(@storage_size))>> ->
        unquote(__MODULE__).to_decimal(data)
    end
  end

  def to_decimal(<<digits::int64>>) do
    Decimal.div(Decimal.new(digits), Decimal.new(100))
  end
  def to_decimal(other) do
    raise ArgumentError, "cannot represent #{inspect(other)} as money, not a valid int64."
  end


  @impl true
  def encode(_state) do
    quote location: :keep do
      %Decimal{} = decimal -> unquote(__MODULE__).to_binary(decimal)
      n when is_float(n) -> unquote(__MODULE__).to_binary(Decimal.from_float(n))
      n when is_integer(n) -> unquote(__MODULE__).to_binary(Decimal.new(n))
      other -> raise ArgumentError, "cannot encode #{inspect(other)} as money."
    end
  end

  def to_binary(%Decimal{coef: coef} = decimal) when coef in [:inf, :qNaN, :sNaN] do
    raise ArgumentError, "cannot represent #{inspect(decimal)} as money type."
  end
  def to_binary(%Decimal{sign: sign, coef: coef, exp: e} = d) do
    case e do
      0 -> encode_int(sign * coef * 100)
      -1 -> encode_int(sign * coef * 10)
      -2 -> encode_int(sign * coef)
      _ -> to_binary(Decimal.round(d, 2))
    end
  end

  defp encode_int(int) when int < @min_int_val do
    raise ArgumentError, "#{inspect(int)} exceeds money's min value #{inspect(@min_int_val)}"
  end
  defp encode_int(int) when @max_int_val < int do
    raise ArgumentError, "#{inspect(int)} exceeds money's max value #{inspect(@max_int_val)}"
  end
  defp encode_int(int) when is_integer(int) do
    <<@storage_size::int32, int::int64>>
  end
end
