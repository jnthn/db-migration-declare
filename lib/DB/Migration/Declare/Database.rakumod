use v6.d;
use DB::Migration::Declare::ColumnType;
use DB::Migration::Declare::Model::MigrationStep;

#| A role done by all supported database backends.
role DB::Migration::Declare::Database {
    #| The name of the database backend.
    method name(--> Str) { ... }

    #| Translate a column type object into the appropriate type name for this database.
    #| If the type is unsupported, returns a type object.
    method translate-type(DB::Migration::Declare::ColumnType $type --> Str) { ... }

    #| Tests if a given column type supports auto-increment.
    method type-supports-increments(DB::Migration::Declare::ColumnType $type --> Bool) { ... }

    #| The expression that produces the current date/time/timestamp in this database for
    #| the specified column type.
    method now-expression(DB::Migration::Declare::ColumnType $type --> Str) { ... }

    #| Translate a migration step to SQL in the up direction. This should be implemented to handle
    #| the various concrete types of migration steps.
    method translate-up(DB::Migration::Declare::Model::MigrationStep $step --> Str) { ... }

    #| Apply a migration to the database using the provided connection object.
    method apply-migration-sql(Any $connection, Str $sql --> Nil) { ... }
}
