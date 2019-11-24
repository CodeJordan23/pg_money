# README

## Intro Short

Adds PostgreSQL's [`money` data type](https://www.postgresql.org/docs/9.5/datatype-money.html) support to `Postgrex`.

## Intro Long
I do integrations, to be more specific, I help my customer to migrate his current [ERP](https://en.wikipedia.org/wiki/Enterprise_resource_planning)-system. The target database is a PostgreSQL database and involves many tables using the `money` data type. To my surprise `Postgrex` doesn't support this data type... for a good reason. Hence the need for this library.

## But!
The usage of `money` should be avoided though as explained in the [PostgreSQL wiki's **Don't do this**](https://wiki.postgresql.org/wiki/Don%27t_Do_This#Don.27t_use_money):

> ### Don't use money
> The `money` data type isn't actually very good for storing monetary values. `Numeric`, or (rarely) `integer` may be better.
> 
> ### Why not?
> lots of reasons.
> 
> It's a fixed-point type, implemented as a machine int, so arithmetic with it is fast. But it doesn't handle fractions of a cent (or equivalents in other currencies), it's rounding behaviour is probably not what you want.
> 
> It doesn't store a currency with the value, rather assuming that all money columns contain the currency specified by the database's lc_monetary locale setting. If you change the `lc_monetary` setting for any reason, all `money` columns **will contain the wrong value**. That means that if you insert `$10.00` while `lc_monetary` is set to `en_US.UTF-8` the value you retrieve may be `10,00 Lei` or `¥1,000` if `lc_monetary` is changed.
> 
> Storing a value as a `numeric`, possibly with the currency being used in an adjacent column, might be better.
> 
> ### When should you?
> If you
> - [ ] are only working in a single currency
> - [ ] aren't dealing with fractional cents
> - [ ] are only doing addition and subtraction
> 
> then money might be the right thing.

... so probably never. Read **Mathias Verraes**' excellent chapter `Emergent Contexts through Refinement` in [DDD - The First 15 Years](https://universities.leanpub.com/ddd_first_15_years) to get a better understanding of currencies.


But this flawed type is out there and needs some interfacing, hence this project.
See how it fails you in a [fail in three acts](FAIL_IN_THREE_ACTS.html).

## Installation

### Option 1, hex.pm

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `pg_money` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pg_money, "~> 0.1.0"}
  ]
end
```

### Option 2, github

Reference it via it's github url:

```elixir
def deps do
  [
    {:pg_money, git: "https://github.com/CodeJordan23/TBD.git"}
  ]
end
```
## Usage

### Postgrex only

```elixir
my_types =
  [
    {PgMoney.Extension, [precision: 2, telemetry_prefix: [:my, :prefix]]}
  ]
Postgrex.Types.define(MyApp.PostgresTypes, my_types, [])

opts = [hostname: "localhost", username: "postgres", database: "pg_money_test", types: MyApp.PostgresTypes ]
# or use PgMoney.Type
{:ok, pid} = Postgrex.Connection.start_link(opts)
```

### with Ecto

You will want to add a new file with your type definition like `postgres_types.ex`
```elixir
Postgrex.Types.define(MyApp.PostgresTypes,
  [{PgMoney.Extension, [precision: 2, telemetry_prefix: [:my, :prefix]]}] ++ Ecto.Adapters.Postgres.extensions(),
  [])
```

and then configure your repository to use it like so:
```elixir
config :my_app, MyApp.Repo, types: MyApp.PostgresTypes
```

Head over to [`Ecto.Adapaters.Postgres`' module extension](https://hexdocs.pm/ecto_sql/Ecto.Adapters.Postgres.html#module-extensions) to learn more.

## License
Copyright 2019 Michael J. Lüttjohann

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## And last but not least

> If I have seen further it is by standing on the shoulders of Giants.
>
> \- Isaac Newton

I want to mention some of these giants and warmly thank all the people involved:
- [PostgreSQL](https://www.postgresql.org/) a great and free database. The well written documentation helped me to write the kick-starter tests for this library.
- [Postgrex](https://hexdocs.pm/postgrex/readme.html)
    For making it so easy to extend.
- [Credo](https://github.com/rrrene/credo/) and [`mix format`](https://hexdocs.pm/mix/master/Mix.Tasks.Format.html) for giving me guidance.
- Plataformatec for hooking me on `Elixir` with their **little Ecto Cookbook** on August 19th. 13 weeks ago...
- Mathias Verraes found at his [homepage](http://verraes.net/) for writing his superb article `Emergent Contexts through Refinement` found here [DDD - The First 15 Years](https://universities.leanpub.com/ddd_first_15_years). Like all the people involved with this book.
- the whole `Elixir` ecosystem. It was fun writing this library.
    - writing documentation was easy and generated easily with `ExDoc`
    - writing tests was seamless.
    - publishing to [hexdocs.pm](https://hexdocs.pm/) seems straigtforward
- [github.com](https://github.com/) and [hexdocs.pm](https://hexdocs.pm/) for hosting this library.