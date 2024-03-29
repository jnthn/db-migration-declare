use v6.d;
use DB::Migration::Declare::ColumnType;
use DB::Migration::Declare::Database;
use Digest::SHA1::Native;

#| The base of all SQL literals.
role DB::Migration::Declare::SQLLiteral {
    method get-sql(DB::Migration::Declare::Database :$database!, DB::Migration::Declare::ColumnType :$expected-type --> Str) { ... }
    method hashed(--> Str) { ... }
}

#| A literal piece of SQL, intended for pass-through to the database and not
#| selected by database.
class DB::Migration::Declare::SQLLiteral::Agnostic does DB::Migration::Declare::SQLLiteral {
    has Str $.sql is required;

    method get-sql(--> Str) {
        $!sql
    }

    method hashed(--> Str) {
        sha1-hex join "\0", "SQLAgnostic", $!sql
    }
}

#| A literal piece of SQL, intended for pass-through to the database and with
#| options per database.
class DB::Migration::Declare::SQLLiteral::Specific does DB::Migration::Declare::SQLLiteral {
    has Str %.options;

    method get-sql(DB::Migration::Declare::Database :$database! --> Str) {
        %!options{$database.name} // fail "No SQL variant provided"
    }

    method hashed(--> Str) {
        sha1-hex join "\0", "SQLSpecific", %!options.sort(*.key).map({ .key, .value })
    }
}

#| Produces the appropriate notion of "now" for the current database backend and column
#| type.
class DB::Migration::Declare::SQLLiteral::Now does DB::Migration::Declare::SQLLiteral {
    method get-sql(DB::Migration::Declare::Database :$database!,
                   DB::Migration::Declare::ColumnType :$expected-type --> Str) {
        $database.now-expression($expected-type)
    }

    method hashed(--> Str) {
        sha1-hex "SQLNow"
    }
}
