defmodule PgMoney.TelemetryTest do
  use ExUnit.Case, async: false
  use PropCheck
  alias PgMoney.TestHelper, as: TH

  setup do
    {:ok, conn} = start_supervised({Postgrex, TH.DB.opts()})
    %{conn: conn, precision: 2}
  end

  test "events are emitted", _ do
    {id, ns} = create_redir(:pg_money_test, self())

    try do
      d = Decimal.new(0)
      PgMoney.Extension.to_int(d, 2, ns)
      {:msg, _} = receive_one()
      assert true
    after
      :telemetry.detach(id)
    end
  end

  property "rounding diff adds up to original", [], _ do
    forall {p, _i, decimal} <- TH.Gen.decimal() do
      {id, ns} = create_redir(:pg_money_test, self())

      try do
        src_diff =
          "1e-#{p + 1}"
          |> Decimal.new()

        subject = Decimal.add(decimal, src_diff)
        PgMoney.Extension.to_int(subject, p, ns)
        {:msg, msg} = receive_one()

        case msg.event do
          [_, :lossy] ->
            summed = Decimal.add(msg.data.dst, msg.data.diff)

            Decimal.eq?(src_diff, msg.data.diff) &&
              Decimal.eq?(subject, msg.meta.src) &&
              Decimal.eq?(subject, summed)

          _ ->
            false
        end
        |> PropCheck.collect(PropCheck.with_title(:precision), p)
      after
        :telemetry.detach(id)
      end
    end
  end

  property "fake precision do not result in fake lossy messages", [] do
    forall {p, _i, decimal} <- TH.Gen.decimal() do
      {id, ns} = create_redir(:pg_money_test, self())

      try do
        factor = "1.#{String.duplicate("0", p + 1)}"
        subject = Decimal.mult(factor, decimal)
        PgMoney.Extension.to_int(subject, p, ns)
        {:msg, msg} = receive_one()

        case msg.event do
          [_, :lossless] ->
            true

          _ ->
            false
        end
        |> PropCheck.collect(with_title(:precision), p)
      after
        :telemetry.detach(id)
      end
    end
  end

  property "integer encoding shouldn't be lossy", [] do
    forall {p, integer} <- {TH.Gen.precision(), TH.Gen.money_int()} do
      {id, ns} = create_redir(:pg_money_test, self())

      try do
        subject = Decimal.new(integer)
        PgMoney.Extension.to_int(subject, p, ns)
        {:msg, msg} = receive_one()

        case msg.event do
          [_, :lossless] ->
            true

          _ ->
            false
        end
        |> PropCheck.collect(with_title(:precision), p)
      after
        :telemetry.detach(id)
      end
    end
  end

  defp create_redir(ns, to) do
    handler_id = UUID.uuid4()

    events = [
      [ns, :lossless],
      [ns, :lossy]
    ]

    :ok =
      :telemetry.attach_many(
        handler_id,
        events,
        &handle_event/4,
        to
      )

    {handler_id, [ns]}
  end

  defp handle_event(msg, data, meta, send_to) do
    send(send_to, %{
      event: msg,
      data: data,
      meta: meta
    })
  end

  defp receive_one(timeout \\ 10) do
    receive do
      msg -> {:msg, msg}
    after
      timeout -> :no_msg
    end
  end
end
