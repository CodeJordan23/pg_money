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
    forall {integer, decimal} <- decimal_within(p) do
      integer == decimal.sign * decimal.coef
    end
  end

  property "echo from db", [], %{conn: conn, precision: p} do
    forall {_, decimal} <- decimal_within(p) do
      [m, n] = echo(conn, decimal)
      assert Decimal.eq?(decimal, n)
      assert Decimal.eq?(decimal, m)
    end
  end

  property "save in temp table", [], %{conn: conn, precision: p} do
    forall {_, decimal} <- decimal_within(p) do
      [m, n] = save_in_temp_table(conn, decimal)
      assert Decimal.eq?(decimal, n)
      assert Decimal.eq?(decimal, m)
    end
  end

  property "symmetry (p=2)", [], %{precision: p} do
    forall {_, decimal} <- decimal_within(p) do
      encoded = PgMoney.Extension.to_int(decimal, p)
      decoded = PgMoney.Extension.to_dec(encoded, p)
      Decimal.eq?(decimal, decoded)
    end
  end

  property "symmetry (p in [0..4])", [], _ do
    forall p <- PropCheck.BasicTypes.integer(0, 4) do
      forall {_, decimal} <- decimal_within(p) do
        encoded = PgMoney.Extension.to_int(decimal, p)
        decoded = PgMoney.Extension.to_dec(encoded, p)
        Decimal.eq?(decimal, decoded)
      end
    end
  end

  defp decimal_within(precision) when is_integer(precision) and 0 <= precision do
    let integer <-
          PropCheck.BasicTypes.integer(
            PgMoney.Extension.min_int_val(),
            PgMoney.Extension.max_int_val()
          ) do
      decimal = %Decimal{coef: abs(integer), exp: -precision, sign: sign(integer)}
      {integer, decimal}
    end
  end

  defp sign(i) when i < 0, do: -1
  defp sign(_), do: 1

  defp echo(conn, %Decimal{} = d) do
    r = Postgrex.query!(conn, "select (#{d})::money, (#{d})::numeric", [])
    [row] = r.rows
    row
  end

  defp save_in_temp_table(conn, %Decimal{} = d) do
    Postgrex.query!(conn, "BEGIN TRANSACTION;", [])

    _ =
      Postgrex.query!(
        conn,
        """
        CREATE TEMP TABLE temp_money ( m money, n numeric )
        ON COMMIT DROP;
        """,
        []
      )

    try do
      _ =
        Postgrex.query!(
          conn,
          """
          INSERT INTO temp_money(m, n)
          VALUES($1, $2);
          """,
          [d, d]
        )

      r = Postgrex.query!(conn, "SELECT * FROM temp_money;", [])
      [row] = r.rows
      row
    after
      Postgrex.query!(conn, "ROLLBACK;", [])
    end
  end
end
