defmodule PgMoney.WithinPrecisionTest do
  use ExUnit.Case, async: true
  use PropCheck

  setup do
    {:ok, conn} = start_supervised({Postgrex, PgMoney.Test.Helper.db_opts()})
    %{conn: conn, precision: 2}
  end

  test "null", %{conn: conn} do
    r = Postgrex.query!(conn, "select null::money", [])
    [[value]] = r.rows
    assert value == nil
  end

  property "integer <-> decimal equivalency", [], %{precision: p} do
    forall {integer, decimal} <- PgMoney.Prop.Helper.decimal_within(p) do
      integer == decimal.sign * decimal.coef
    end
  end

  property "echo from db", [], %{conn: conn, precision: p} do
    forall {_, decimal} <- PgMoney.Prop.Helper.decimal_within(p) do
      [m, n] = PgMoney.Prop.Helper.echo(conn, decimal)
      assert Decimal.eq?(decimal, n)
      assert Decimal.eq?(decimal, m)
    end
  end

  property "save in temp table", [], %{conn: conn, precision: p} do
    forall {_, decimal} <- PgMoney.Prop.Helper.decimal_within(p) do
      [m, n] = PgMoney.Prop.Helper.save_in_temp_table(conn, decimal)
      assert Decimal.eq?(decimal, n)
      assert Decimal.eq?(decimal, m)
    end
  end

  property "symmetry", [numtests: 10_000], _ do
    forall {p, {i, decimal}} <- PgMoney.Prop.Helper.decimal_any_precision() do
      encoded = PgMoney.Extension.to_int(decimal, p)
      decoded = PgMoney.Extension.to_dec(encoded, p)

      Decimal.eq?(decimal, decoded)
      |> collect(
        with_title(:symmetry_precision),
        p
      )
      |> collect(
        with_title(:symmetry_buckets),
        PgMoney.Prop.Helper.to_range(50, abs(i))
      )
      |> collect(
        PropCheck.with_title(:symmetry_sign),
        case {i, decimal.sign} do
          {0, _} -> :zero
          {_, 1} -> :pos
          _ -> :neg
        end
      )
    end
  end

  property "symmetry II", [numtests: 1_000], _ do
    forall p <- PropCheck.BasicTypes.integer(1, 5) do
      forall {i, decimal} <- PgMoney.Prop.Helper.decimal_within(p - 1) do
        encoded = PgMoney.Extension.to_int(decimal, p)
        decoded = PgMoney.Extension.to_dec(encoded, p)

        Decimal.eq?(decimal, decoded)
        |> collect(
          with_title(:symmetry_precision),
          p
        )
        |> collect(
          with_title(:symmetry_buckets),
          PgMoney.Prop.Helper.to_range(50, abs(i))
        )
        |> collect(
          PropCheck.with_title(:symmetry_sign),
          decimal.exp + p
        )
      end
    end
  end
end
