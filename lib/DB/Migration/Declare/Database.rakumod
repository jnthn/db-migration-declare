use v6.d;
use DB::Migration::Declare::ColumnType;

#| A role done by all supported databsae backends.
role DB::Migration::Declare::Database {
    #| The name of the database backend.
    method name(--> Str) { ... }

    #| The expression that produces the current date/time/timestamp in this database for
    #| the specified column type.
    method now-expression(DB::Migration::Declare::ColumnType $type --> Str) { ... }
}
