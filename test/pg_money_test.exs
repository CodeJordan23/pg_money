defmodule PgMoneyTest do
  use PgMoney.TestCase

  test "can connect", %{conn: conn} do
    r = Postgrex.query!(conn, "select 42", [])

    assert r.num_rows == 1
    assert r.rows == [[42]]
  end

  test "storage size" do
    assert PgMoney.storage_size() == 8
  end

  test "range" do
    assert Decimal.eq?(PgMoney.min(2), "-92233720368547758.08")
    assert Decimal.eq?(PgMoney.max(2), "+92233720368547758.07")
  end
end
