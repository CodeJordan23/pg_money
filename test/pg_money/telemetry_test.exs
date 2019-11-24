defmodule PgMoney.TelemetryTest do
  use PgMoney.TestCase, async: true

  @namespace :telemetry_test
  @diff_postfixes ~w(lossless lossy)a
  @exec_postfixes ~w(start stop)a
  @all_postfixes @exec_postfixes ++ @diff_postfixes

  test "events are emitted", _ do
    {id, ns} = register_telemetry()

    try do
      d = Decimal.new(0)
      Ext.to_int(d, 2, ns)
      {:msg, _} = receive_one()
      assert true
    after
      :telemetry.detach(id)
    end
  end

  property "rounding diff adds up to original", [], _ do
    forall {p, _i, decimal} <- Gen.decimal() do
      {id, ns} = register_telemetry()

      try do
        src_diff =
          "1e-#{p + 1}"
          |> Decimal.new()

        subject = Decimal.add(decimal, src_diff)
        Ext.to_int(subject, p, ns)
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
    forall {p, _i, decimal} <- Gen.decimal() do
      {id, ns} = register_telemetry()

      try do
        factor = "1.#{String.duplicate("0", p + 1)}"
        subject = Decimal.mult(factor, decimal)
        Ext.to_int(subject, p, ns)
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
    forall {p, integer} <- {Gen.precision(), Gen.money_int()} do
      {id, ns} = register_telemetry()

      try do
        subject = Decimal.new(integer)
        Ext.to_int(subject, p, ns)
        {:msg, msg} = receive_one()

        case msg.event do
          [_, :lossless] ->
            true

          _ ->
            false
        end
        |> collect(with_title(:precision), p)
      after
        :telemetry.detach(id)
      end
    end
  end

  property "total time it takes...", [:verbose], %{precision: p} do
    forall {p, _i, decimal} <- Gen.decimal(p) do
      {id, ns} = register_telemetry(create_events([:stop]))

      try do
        encoded = Ext.to_int(decimal, p, ns)
        _decoded = Ext.to_dec(encoded, p, ns)

        total_duration =
          1..2
          |> Enum.reduce(0, fn _el, acc ->
            {:msg, msg} = receive_one()
            acc + msg.data.duration
          end)

        assert total_duration == 0
      after
        :telemetry.detach(id)
      end
    end
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

  defp receive_exec(timeout \\ 10) do
    @exec_postfixes
    |> Enum.map(fn _ep ->
      receive do
        msg -> {:ok, msg}
      after
        timeout -> nil
      end
    end)
  end

  defp create_events(events, ns \\ @namespace) do
    events
    |> Enum.map(fn ev -> [ns, ev] end)
  end

  defp diff_events(ns \\ @namespace) do
    create_events(@diff_postfixes, ns)
  end

  defp exec_events(ns \\ @namespace) do
    create_events(@exec_postfixes, ns)
  end

  defp register_telemetry do
    register_telemetry(diff_events())
  end

  def register_telemetry(events, ns \\ @namespace)

  def register_telemetry(events, ns) do
    handler_id = UUID.uuid4()

    :ok =
      :telemetry.attach_many(
        handler_id,
        events,
        &handle_event/4,
        self()
      )

    {handler_id, [ns]}
  end
end
