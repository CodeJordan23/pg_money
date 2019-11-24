defmodule PgMoney do
  @moduledoc """
  Contains the all the basic types and guards to work with the `money` data type.
  """

  @type money :: -9_223_372_036_854_775_808..9_223_372_036_854_775_807
  @type precision :: non_neg_integer()
  @type telemetry :: false | nonempty_list(atom())
  @type config :: %{
          precision: precision(),
          telemetry: telemetry()
        }

  @storage_size 8

  @minimum -9_223_372_036_854_775_808
  @maximum +9_223_372_036_854_775_807

  @doc """
  The minimum integer value possible for the `money` data type.
  """
  @spec minimum :: neg_integer()
  def minimum, do: @minimum

  @doc """
  The maximum integer value possible for the `money` data type.
  """
  @spec maximum :: pos_integer()
  def maximum, do: @maximum

  @doc """
  The storage size the `money` data type takes up in the database.
  """
  @spec storage_size :: non_neg_integer()
  def storage_size, do: @storage_size

  @doc """
  Returns the maximum `Decimal.t()` value for the given `precision`.
  """
  @spec max(precision()) :: Decimal.t()
  def max(precision),
    do:
      Decimal.div(
        @maximum,
        pow(10, precision)
      )

  @doc """
  Returns the minimum `Decimal.t()` value for the given `precision`.
  """
  @spec min(precision()) :: Decimal.t()
  def min(precision),
    do:
      Decimal.div(
        @minimum,
        pow(10, precision)
      )

  defp pow(_, 0), do: 1
  defp pow(n, 1), do: n
  defp pow(n, 2), do: square(n)

  defp pow(n, x) do
    case Integer.mod(x, 2) do
      0 ->
        x = trunc(x / 2)
        square(pow(n, x))

      1 ->
        n * pow(n, x - 1)
    end
  end

  defp square(x), do: x * x

  @doc """
  Returns `true` if `value` is an integer and falls between the `minimum/0` and `maximum/0` (inclusive) range of the `money` data type.
  """
  defguard is_money(value) when is_integer(value) and @minimum <= value and value <= @maximum

  @doc """
  Returns `true` if `value` is a valid `t:precision/0`, false otherwise.
  """
  defguard is_precision(value) when is_integer(value) and 0 <= value

  @doc """
  Returns `true` if `value` is a valid `t:telemetry/0`, false otherwise.
  """
  defguard is_telemetry(value) when value == false or (is_list(value) and length(value) > 0)
end
