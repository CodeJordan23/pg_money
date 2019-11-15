defmodule PgMoney.Extension do
  @moduledoc """
  Implements how to encode and decode PostgeSQL's `money` data type.
  """

  @behaviour Postgrex.Extension
  import Postgrex.BinaryUtils

  @min_int_val -9_223_372_036_854_775_808
  @max_int_val +9_223_372_036_854_775_807
  @storage_size 8

  def min_int_val, do: @min_int_val
  def max_int_val, do: @max_int_val
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
        unquote(__MODULE__).decode_numeric(data)
    end
  end

  def decode_numeric(<<digits::int64>>) do
    Decimal.div(Decimal.new(digits), Decimal.new(100))
  end

  @impl true
  def encode(_state) do
    quote location: :keep do
      %Decimal{} = decimal -> unquote(__MODULE__).encode_numeric(decimal)
      n when is_float(n) -> unquote(__MODULE__).encode_numeric(Decimal.from_float(n))
      n when is_integer(n) -> unquote(__MODULE__).encode_numeric(Decimal.new(n))
    end
  end

  ## Helpers

  def encode_numeric(%Decimal{coef: coef} = decimal) when coef in [:inf, :qNaN, :sNaN] do
    raise ArgumentError, "cannot represent #{inspect(decimal)} as money type"
  end

  def encode_numeric(%Decimal{sign: sign, coef: coef, exp: 0}), do: encode_int(sign * coef * 100)
  def encode_numeric(%Decimal{sign: sign, coef: coef, exp: -1}), do: encode_int(sign * coef * 10)
  def encode_numeric(%Decimal{sign: sign, coef: coef, exp: -2}), do: encode_int(sign * coef)
  def encode_numeric(%Decimal{} = dec), do: encode_numeric(Decimal.round(dec, 2))

  defp encode_int(int) when is_integer(int) and int < @min_int_val do
    raise ArgumentError, "#{inspect(int)} exceeds money's min value #{inspect(@min_int_val)}"
  end

  defp encode_int(int) when is_integer(int) and @max_int_val < int do
    raise ArgumentError, "#{inspect(int)} exceeds money's max value #{inspect(@max_int_val)}"
  end

  defp encode_int(int) when is_integer(int) do
    <<@storage_size::int32, int::int64>>
  end
end
