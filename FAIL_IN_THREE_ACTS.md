# A Fail In Three Acts

As stated in the [README.md](readme.html) the `money` data type is flawed. Basically it is a `64`-bit signed integer and the connection's current `lc_monetary` settings dictates how to interpret it.

Let's see what this means:

## Analysis


### Preludium
```sql
BEGIN TRANSACTION;

CREATE TEMP TABLE money_test
  ( m money
  , n numeric
  )
ON COMMIT DROP;

SHOW lc_monetary;
```
**Result:** `German_Germany.1252`


### Act I
```sql
INSERT INTO money_test
  ( m
  , n
  )
VALUES
  ( 12345.6789
  , 12345.6789
  );

SELECT * FROM money_test;
```
**Result:**

    | m           | n          |
    |------------:|-----------:|
    | 12.345,68 € | 12345.6789 |


### Interludium
```sql
SET lc_monetary to 'Arabic_Bahrain';
-- because I am coding on a windows machine
-- use 'ar_BH.utf8' on anything else, but no warranty.
-- for this example anything that has another precision than your database's default will do.
-- My cofinguration is two digit preecision, so here I'll switch over to three.
SHOW lc_monetary;
```
**Result:** `Arabic_Bahrain`


### Act II
```sql
INSERT INTO money_test
  ( m
  , n
  )
VALUES
  ( 12345.6789
  , 12345.6789
  );

SELECT * FROM money_test;
```
**Result:**

    |  m         | n          |
    |-----------:|-----------:|
    |  1,234.568 | 12345.6789 |
    | 12,345.679 | 12345.6789 |


### Act III
```sql
RESET lc_monetary; -- switch back
SELECT * FROM money_test;
```
**Result:**

    | m            | n          |
    |-------------:|-----------:|
    |  12.345,68 € | 12345.6789 |
    | 123.456,79 € | 12345.6789 |


### Le fin
```sql
ROLLBACK;
```

## Conclusion
As a developer we **should not** mess with `lc_monetary`, change it during the application's life time and respect the database defaults.

Furthermore, when using `Postgrex` or `Ecto`, all extensions need to be set up at compile time.