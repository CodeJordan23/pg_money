# PgMoney

Adds PostgreSQL's [`money` data type] support (https://www.postgresql.org/docs/9.5/datatype-money.html) to `Postgrex`.

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

But this flawed type is out there and needs some interfacing, hence this project.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `pg_money` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pg_money, "~> 0.1.0"}
  ]
end
```

## License
Copyright [2019] [Michael J. Lüttjohann]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.