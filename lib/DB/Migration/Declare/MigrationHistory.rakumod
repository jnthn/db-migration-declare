use v6.d;
use DB::Migration::Declare::MigrationDirection;

#| The history of the application of a set of migrations to a database.
class DB::Migration::Declare::MigrationHistory {
    #| A single migration entry in the history.
    class Entry {
        #| Version number of the database.
        has Int $.version is required;

        #| Hash of the migration that was applied.
        has Str $.hash is required;

        #| The direction of the migration.
        has MigrationDirection $.direction is required;

        #| The stored description of the migration.
        has Str $.description is required;

        #| The date/time when the migration was applied.
        has DateTime $.applied-at is required;
    }

    #| The set of entries in the migration history.
    has Entry @.entries is required;
}
