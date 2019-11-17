defmodule PgMoney.WithinPrecisionTest do
  use ExUnit.Case, async: true
  use PropCheck
  alias PgMoney.TestHelper, as: TH

  setup do
    {:ok, conn} = start_supervised({Postgrex, TH.DB.opts()})
    %{conn: conn, precision: 2}
  end

  test "null", %{conn: conn} do
    r = Postgrex.query!(conn, "select null::money", [])
    [[value]] = r.rows
    assert value == nil
  end

  property "integer <-> decimal equivalency", [], %{precision: p} do
    forall {^p, integer, decimal} <- TH.Gen.decimal(p) do
      integer == decimal.sign * decimal.coef
    end
  end

  property "echo from db", [], %{conn: conn, precision: p} do
    forall {^p, _, decimal} <- TH.Gen.decimal(p) do
      [m, n] = TH.DB.echo(conn, decimal)
      assert Decimal.eq?(decimal, n)
      assert Decimal.eq?(decimal, m)
    end
  end

  property "save in temp table", [], %{conn: conn, precision: p} do
    forall {^p, _, decimal} <- TH.Gen.decimal(p) do
      [m, n] = TH.DB.save_in_temp_table(conn, decimal)
      assert Decimal.eq?(decimal, n)
      assert Decimal.eq?(decimal, m)
    end
  end

  property "symmetry", [numtests: 10_000], _ do
    forall {p, i, decimal} <- TH.Gen.decimal() do
      encoded = PgMoney.Extension.to_int(decimal, p)
      decoded = PgMoney.Extension.to_dec(encoded, p)

      Decimal.eq?(decimal, decoded)
      |> collect(
        with_title(:symmetry_precision),
        p
      )
      |> collect(
        with_title(:symmetry_buckets),
        TH.to_range(50, abs(i))
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
    forall p_high <- TH.Gen.precision(1, 5) do
      forall {_p_low, i, decimal} <- TH.Gen.decimal(p_high - 1) do
        encoded = PgMoney.Extension.to_int(decimal, p_high)
        decoded = PgMoney.Extension.to_dec(encoded, p_high)

        Decimal.eq?(decimal, decoded)
        |> collect(
          with_title(:symmetry_precision),
          p_high
        )
        |> collect(
          with_title(:symmetry_buckets),
          TH.to_range(50, abs(i))
        )
        |> collect(
          PropCheck.with_title(:symmetry_sign),
          decimal.exp + p_high
        )
      end
    end
  end
end
