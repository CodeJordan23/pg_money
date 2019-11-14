defmodule PgMoney.Test.Helper do
  def db_opts do
    [
      username: "postgres",
      database: "pg_money_test",
      types: PgMoney.PostgresTypes
    ]
  end
end

ExUnit.start()
