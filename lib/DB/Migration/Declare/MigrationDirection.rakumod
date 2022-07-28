use v6.d;
unit package DB::Migration::Declare;

#| The direction of a migration.
enum MigrationDirection is export <Up Down>;
