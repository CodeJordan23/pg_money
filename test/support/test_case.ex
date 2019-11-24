defmodule PgMoney.TestCase do
  @moduledoc """
  This module defines the common setup for all tests inside this project.
  """

  import PgMoney
  alias PgMoney.TestCase.DB

  import PropCheck
  alias PropCheck, as: PC
  use ExUnit.CaseTemplate

  using do
    quote do
      use PropCheck
      alias PropCheck, as: PC

      import PgMoney
      alias PgMoney.Extension, as: Ext
      import PgMoney.TestCase
      alias PgMoney.TestCase.DB
      alias PgMoney.TestCase.Gen
    end
  end

  setup do
    {:ok, conn} = start_supervised({Postgrex, DB.opts()})
    %{conn: conn, precision: 2}
  end

  def to_range(m, n) do
    base = div(n, m)
    {base * m, (base + 1) * m}
  end

  defmodule Gen do
    @moduledoc """
    Provides relevant generators for property-based testing.
    """

    @spec precision(non_neg_integer(), non_neg_integer()) :: :proper_types.type()
    def precision(low \\ 0, high \\ 4)

    def precision(low, high) do
      PC.BasicTypes.integer(low, high)
    end

    @spec money_int :: :proper_types.type()
    def money_int do
      PC.BasicTypes.integer(minimum(), maximum())
    end

    @spec decimal :: :proper_types.type()
    def decimal do
      let p <- precision() do
        decimal(p)
      end
    end

    @spec decimal(PgMoney.precision()) :: :proper_types.type()
    def decimal(precision) when is_precision(precision) do
      let integer <- money_int() do
        decimal = %Decimal{coef: abs(integer), exp: -precision, sign: sign(integer)}
        {precision, integer, decimal}
      end
    end

    defp sign(i) when i < 0, do: -1
    defp sign(_), do: 1
  end

  defmodule DB do
    @moduledoc """
    This module groups database related stuff.
    """

    def opts do
      [
        username: "postgres",
        database: "pg_money_test",
        types: PgMoney.PostgresTypes
      ]
    end

    @spec echo(Postgrex.conn(), Decimal.t()) :: nonempty_list(Decimal.t())
    def echo(conn, %Decimal{} = d) do
      r = Postgrex.query!(conn, "select (#{d})::money, (#{d})::numeric", [])
      [row] = r.rows
      row
    end

    @spec save_in_temp_table(Postgrex.conn(), Decimal.t()) :: nonempty_list(Decimal.t())
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
end
