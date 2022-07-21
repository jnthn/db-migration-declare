use v6.d;
use DB::Migration::Declare::Database;

#| Postgres-specific checks, code generation, and migration application.
class DB::Migration::Declare::Database::Postgres does DB::Migration::Declare::Database {
    method name(--> Str) { 'postgres' }

    method now-expression(DB::Migration::Declare::ColumnType $type --> Str) {
        given $type {
            when DB::Migration::Declare::ColumnType::Date {
                'current_date'
            }
            when DB::Migration::Declare::ColumnType::Timestamp {
                'current_timestamp'
            }
            default {
                fail "Cannot provide a now value for column of type '$type.describe()'";
            }
        }
    }

}
