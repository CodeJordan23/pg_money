defmodule PgMoney.WithinPrecisionTest do
  use PgMoney.TestCase

  test "null", %{conn: conn} do
    r = Postgrex.query!(conn, "select null::money", [])
    [[value]] = r.rows
    assert value == nil
  end

  property "integer <-> decimal equivalency", [], %{precision: p} do
    forall {^p, integer, decimal} <- Gen.decimal(p) do
      integer == decimal.sign * decimal.coef
    end
  end

  property "echo from db", [], %{conn: conn, precision: p} do
    forall {^p, _, decimal} <- Gen.decimal(p) do
      [m, n] = DB.echo(conn, decimal)
      assert Decimal.eq?(decimal, n)
      assert Decimal.eq?(decimal, m)
    end
  end

  property "save in temp table", [], %{conn: conn, precision: p} do
    forall {^p, _, decimal} <- Gen.decimal(p) do
      [m, n] = DB.save_in_temp_table(conn, decimal)
      assert Decimal.eq?(decimal, n)
      assert Decimal.eq?(decimal, m)
    end
  end

  property "symmetry", [numtests: 10_000], _ do
    forall {p, i, decimal} <- Gen.decimal() do
      encoded = Ext.to_int(decimal, p)
      decoded = Ext.to_dec(encoded, p)

      Decimal.eq?(decimal, decoded)
      |> collect(
        with_title(:symmetry_precision),
        p
      )
      |> collect(
        with_title(:symmetry_buckets),
        to_range(50, abs(i))
      )
      |> collect(
        with_title(:symmetry_sign),
        case {i, decimal.sign} do
          {0, _} -> :zero
          {_, 1} -> :pos
          _ -> :neg
        end
      )
    end
  end

  property "symmetry II", [numtests: 1_000], _ do
    forall p_high <- Gen.precision(1, 5) do
      forall {_p_low, i, decimal} <- Gen.decimal(p_high - 1) do
        encoded = Ext.to_int(decimal, p_high)
        decoded = Ext.to_dec(encoded, p_high)

        Decimal.eq?(decimal, decoded)
        |> collect(
          with_title(:symmetry_precision),
          p_high
        )
        |> collect(
          with_title(:symmetry_buckets),
          to_range(50, abs(i))
        )
        |> collect(
          with_title(:symmetry_sign),
          decimal.exp + p_high
        )
      end
    end
  end
end
