# DB::Migration::Declare

**Warning**: The module should currently be considered an early BETA. For the
immediate future only Postgres support is planned.

A Raku module for specifying database migrations. Of note:

* Migrations are written in a Raku-based DSL, meaning they are fully syntax
  checked
* In most cases, only "up" migrations (to higher versions) need be specified,
  and the "down" migration (to earlier versions) will be calculated
* Migrations can be dry-run from a test case. Attempting to drop a column that
  never existed, for example, will be detected and cause a test failure, so
  problems can be caught before the migration is deployed.
* The final state produced by the migrations can be dumped, so it is possible
  to understand the final state of the database.

If one is using a Raku ORM such as Red, it is probably worth looking into how
it might assist with migrations. This module is more aimed at those writing
their queries in SQL, perhaps using something like Badger to have those SQL
queries neatly wrapped up in Raku subs and thus avoid inline SQL.
