defmodule PgMoneyTest do
  use ExUnit.Case, async: true
  use PropCheck

  setup do
    {:ok, conn} = start_supervised({Postgrex, PgMoney.TestHelper.DB.opts()})

    %{conn: conn, precision: 2}
  end

  test "can connect", %{conn: conn} do
    r = Postgrex.query!(conn, "select 42", [])

    assert r.num_rows == 1
    assert r.rows == [[42]]
  end
end
