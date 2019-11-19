defmodule PgMoneyTest do
  use PgMoney.TestCase

  test "can connect", %{conn: conn} do
    r = Postgrex.query!(conn, "select 42", [])

    assert r.num_rows == 1
    assert r.rows == [[42]]
  end
end
