defmodule PgMoney.Test.Helper do
  def db_opts do
    [
      username: "postgres",
      database: "pg_money_test",
      types: PgMoney.PostgresTypes
    ]
  end
end

defmodule PgMoney.Prop.Helper do
  import PropCheck
  import PgMoney

  def to_range(m, n) do
    base = div(n, m)
    {base * m, (base + 1) * m}
  end

  def decimal_any_precision() do
    let p <- PropCheck.BasicTypes.integer(0, 4) do
      let dw <- decimal_within(p) do
        {p, dw}
      end
    end
  end

  def decimal_within(precision) when is_precision(precision) do
    let integer <-
          PropCheck.BasicTypes.integer(
            PgMoney.minimum(),
            PgMoney.maximum()
          ) do
      decimal = %Decimal{coef: abs(integer), exp: -precision, sign: sign(integer)}
      {integer, decimal}
    end
  end

  def sign(i) when i < 0, do: -1
  def sign(_), do: 1

  def echo(conn, %Decimal{} = d) do
    r = Postgrex.query!(conn, "select (#{d})::money, (#{d})::numeric", [])
    [row] = r.rows
    row
  end

  def save_in_temp_table(conn, %Decimal{} = d) do
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

ExUnit.start()
