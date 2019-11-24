# Lessons learned

## How to create a Postgrex extension

1. add `{:postgrex, ">= 0.0.0"}` to `mix.exs`
2. implement `Postgrex.Extension`'s callbacks
      1. `c:Postgrex.Extension.init/1`
      2. `c:Postgrex.Extension.matching/1`
      3. `c:Postgrex.Extension.format/1`
      4. `c:Postgrex.Extension.encode/1`
      5. `c:Postgrex.Extension.decode/1`
3. enable during compile time

    ```elixir
    Postgrex.Types.define(
      PgMoney.PostgresTypes,
      [PgMoney.Extension],
      []
    )
    ```
    see `Postgrex.Types.define/3` for more.

## How to do property-based testing
1. add `{:propcheck, "~> 1.1", only: [:test, :dev]}` to your mix dependencies.
2. in your tests, for example `property_test.exs`:
    ```elixir
    defmodule My.PropertyTest do
      use PropCheck
      setup do
        test_ctx = nil
        test_ctx
      end

      property "name", prop_cfg, test_ctx do
        # do prop-testing
      end
    end
    ```
3. do property-based testing :P

- understood how `PropCheck.collect/3` works:
    ```elixir
    test = expected == actual
    test
    |> collect(
      with_title("how to collect and set a header"),
      my_sample
    )
    |> collect(
      with_title("chain and collect"),
      more_samples
    )
    ```

    To my first surprise this results in:
        
        chain and collect
        ...

        how to collect and set a header
        ...

    Turns out to be right, because the equivalent looks like this:

    ```elixir
    collect(
      collect(
        test,
        with_title("how to collect and set a header"),
        my_sample
      ),
      with_title("chain and collect"),
      more_samples
    )
    ```
- properties I tested:
    - symmetry or *there and back again*:
        ```elixir
        # lib level
        expected = 2
        ^expected =
          expected
          |> PgMoney.Extension.to_dec()
          |> PgMoney.Extension.to_int()

        # db level
        # saving involves (hopefully) encoding and decoding
        [m, n] = DB.save_in_temp_table(conn, decimal)
        assert Decimal.eq?(decimal, n)
        assert Decimal.eq?(decimal, m)
        ```
    - `test oracle` and `different paths, same destination`

        `[m, n] = DB.save_in_temp_table(conn, decimal)` could also be seen as a `test oracle` or  `different paths, same destination`. This is what happens:

        ```
                      [insert]
                       |    |
        [store as money]    [store as numeric]
                       |    |
                       [read]
                       |    |
                       m == n
        ```

        We can build upon `Postgrex` handling of `Decimal` as a PostgreSQL `numeric` and compare it with the corresponding `money`value. Based on this principle, or at least how I implemented it, we go different paths and arrive at the same destination.
- more:
    - [Choosing properties for property-based testing](https://fsharpforfunandprofit.com/posts/property-based-testing-2/)


## How to do telemetry
- add `{:telemetry, "~> 0.4.0"}` to your mix dependencies.
- emit an event with `:telemetry.execute/2` or `:telemetry.execute/3`
- to listen to an event you have to attach a handler via `:telemetry.attach/4` or `:telemetry.attach_many/4`
- if there is no interest in receiving the attached events you `:telemetry.detach/1` your `:telemetry.handler_id()`
- if you want to correctly measure elapsed time use `:erlang.monotonic_time/0` and `:erlang.monotonic_time/1`
- based on my test I would like to remove the `:start` and `:stop` events as the duration is always `0 ns` on my computer.
- read more on Samuel Mullen's blog post [The "How"s, "What"s, and "Why"s of Elixir Telemetry](https://samuelmullen.com/articles/the-hows-whats-and-whys-of-elixir-telemetry/)

## Follow up
- learn when `:erlang` does a process context switch.

    in my humble understanding that I have right now, I wanted to avoid having this during instrumentation. Hence I emit the `:start` and `:stop` events inside the `after` block like this:

    ```elixir
    def to_dec(integer, precision, telemetry) do
        started_at = current_time()

        try do
          case {PgMoney.is_money(integer), PgMoney.is_precision(precision)} do
            # implementation
          end
        after
          duration = time_diff(started_at, current_time())
          emit_start(telemetry, :to_dec, started_at)
          emit_stop(telemetry, :to_dec, duration)
        end
      end
    ```

- extend and write better properties
  
    Right now I have only touched the surface with `within_precision_test.exs`. The next steps would be to:
    
    1. write properties relating to lossy operations
    2. generalize it to any precision

- I built the foundation to implement a ledger who tracks rounding losses like laid out in **Mathias Verraes**' article `Emergent Contexts through Refinement` found in [DDD - The First 15 Years](https://universities.leanpub.com/ddd_first_15_years). But this is a topic for another time.

