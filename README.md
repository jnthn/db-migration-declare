# DB::Migration::Declare

Database migrations are an ordered, append-only list of database change
operations that together bring the database up to a current schema. A table
in the database is used to track which migrations have been applied so far,
so that the database can be brought up to date by applying the latest
migrations.

This module allows one to specify database migrations using a Raku DSL. The
migrations are checked in various ways for correctness (for example, trying
to drop a table that never existed, or adding duplicate columns), and are
then translated into SQL and applied to the database.

If one is using a Raku ORM such as Red, it is probably worth looking into how
it might assist with migrations. This module is more aimed at those writing
their queries in SQL, perhaps using something like Badger to have those SQL
queries neatly wrapped up in Raku subs and thus avoid inline SQL.

**Warning**: The module should currently be considered an early BETA. For the
immediate future only Postgres support is planned, although if somebody shows
up with a PR for another database, it will be gladly received!

## Getting Started

### Writing migrations

Migrations can be written in a single file or spread over multiple files in a
single directory, where the filenames will be used as the ordering. For now
we'll assume there is a single file `migrations.raku` where the migrations
will be written one after the other.

A migration file with a single migration looks like this:

```raku
use DB::Migration::Declare;

migration 'Setup', {
    create-table 'skyscrapers', {
        add-column 'id', integer(), :increments, :primary;
        add-column 'name', text(), :!null, :unique;
        add-column 'height', integer(), :!null;
    }
}
```

Future changes to the database are specified by writing another migration
at the end of the file. For example, after adding another migration the
file overall could look as follows:

```raku
use DB::Migration::Declare;

migration 'Setup', {
    create-table 'skyscrapers', {
        add-column 'id', integer(), :increments, :primary;
        add-column 'name', text(), :!null, :unique;
        add-column 'height', integer(), :!null;
    }
}

migration 'Add countries', {
    create-table 'countries', {
        add-column 'id', integer(), :increments, :primary;
        add-column 'name', varchar(255), :!null, :unique;
    }

    alter-table 'skyscrapers',{
        add-column 'country', integer();
        foriegn-key table => 'countries', from => 'country', to => 'id';
    }
}
```

### Testing migrations

When a project has migrations, it is wise to write a test case to check that
the list of migrations are well-formed. This following can be placed in a
`t/migrations.rakutest`:

```raku
use DB::Migration::Declare::Database::Postgres;
use DB::Migration::Declare::Test;
use Test;

check-migrations
        source => $*PROGRAM.parent.parent.add('migrations.raku'),
        database => DB::Migration::Declare::Database::Postgres.new;

done-testing;
```

Which will produce the output:

```
ok 1 - Setup
ok 2 - Add countries
1..2
```

If we were to introduce an error into the migration:

```
    alter-table 'skyskrapers',{
        add-column 'country', integer();
        foriegn-key table => 'countries', from => 'country', to => 'id';
    }
```

The test would fail:

```
ok 1 - Setup
not ok 2 - Add countries
# Failed test 'Add countries'
# Migration at migrations.raku:11 has problems:
#   Cannot alter non-existent table 'skyskrapers'
1..2
# You failed 1 test of 2
```

With diagnostics indicating what is wrong. (If following this getting started
guide like a tutorial, undo the change introducing an error before continuing!)

### Applying migrations

To migrate a database to the latest version, assuming we are placing this in
a `service.raku` script, do this:

```
use DB::Migration::Declare::Applicator;
use DB::Migration::Declare::Database::Postgres;
use DB::Pg;

my $conn = $pg.new(:conninfo('...write your connection string here...'));

my $applicator = DB::Migration::Declare::Applicator.new:
        schema-id => 'my-project',
        source => $*PROGRAM.parent.add('migrations.raku'),
        database => DB::Migration::Declare::Database::Postgres.new,
        connection => $conn;
my $status = $applicator.to-latest;
note "Applied $status.migrations.elems() migration(s)";
```

Depending on your situation, you might have this as a distinct script, or
place it in the startup script for a Cro service to run the migrations upon
startup.
