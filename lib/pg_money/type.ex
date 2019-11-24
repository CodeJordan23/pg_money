Postgrex.Types.define(
  PgMoney.Type,
  [{PgMoney.Extension, [precision: 2, telemetry_prefix: [:pg_money]]}],
  []
)
