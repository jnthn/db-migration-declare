use v6.d;
use DB::Migration::Declare::Database;
use DB::Migration::Declare::MigrationDirection;
use DB::Migration::Declare::Model;
use DB::Migration::Declare::Schema;

#| Exception thrown when there is inconsistent migration history in the specification versus
#| the database migration history.
class X::DB::Migration::Declare::InconsistentHistory is Exception {
    #| The description of the migration in the declarative specification (code).
    has Str $.specification-description is required;

    #| The hash of the migration in the declarative specification (code).
    has Str $.specification-hash is required;

    #| The file where the migration specification is located.
    has Str $.specification-file is required;

    #| The line number where the migration specification is located.
    has Int $.specification-line is required;

    #| The description of the migration in the stored history (database).
    has Str $.stored-description is required;

    #| The hash of the migration in the stored history (database).
    has Str $.stored-hash is required;

    #| The version number where there is an inconsistency.
    has Int $.version is required;

    method message(--> Str) {
        if $!version == 1 {
            "The first migration '$!specification-description' ($!specification-file:$!specification-line)\n" ~
                "does not match with the first migration applied to the database.\n" ~
                "It may have been modified accidentally, or the wrong migrations may\n" ~
                "be being applied to the database."
        }
        elsif $!specification-description eq $!stored-description {
            "The migration '$!specification-description' ($!specification-file:$!specification-line)\n" ~
                "appears to have changed in the source code since it was applied.\n" ~
                "Applied migration specifications must not be changed after they are\n" ~
                "applied; consider using version control history to diagnose and fix this."
        }
        else {
            "The migration '$!specification-description' ($!specification-file:$!specification-line)\n" ~
                "does not match the observed migration '$!stored-description' in the databas.\n" ~
                "Changes to migrations that have already been applied, or insertions/deletions of\n" ~
                "migrations to the specification, are not allowed. Consider using version control\n" ~
                "history to diagnose and fix this."
        }
    }
}

#| Loads migrations and applies them to a target database.
class DB::Migration::Declare::Applicator {
    #| An ID identifying the schema that is established/managed by this migration.
    #| Used in order to differentiate different migrations that are applied to the
    #| same logical database. (It is up to the user of this module to ensure the
    #| established tables do not overlap.)
    has Str $.schema-id is required;

    #| Migration file or directory of migration files.
    has IO::Path $.source is required;

    #| The database backend to use.
    has DB::Migration::Declare::Database $.database is required;

    #| The database connection object to use.
    has Any $.connection is required;

    #| Loaded list of migrations.
    has DB::Migraion::Declare::Model::MigrationList $!migration-list .= new;

    #| The schema that we built, if any.
    has DB::Migration::Declare::Schema $!schema;

    submethod TWEAK(--> Nil) {
        # Obtain migration files to load, in order.
        my @files = do if $!source.f {
            $!source
        }
        elsif $!source.d {
            $!source.dir(test => *.f).sort(~*)
        }
        else {
            die "Could not find a migration file or directory at '$!source'";
        }

        # Load them and add them to the migration list.
        for @files {
            my $*DMD-MIGRATION-LIST = $!migration-list;
            EVALFILE $_;
        }
    }

    #| Check that the migrations make sense. Note that this is not required as a separate step
    #| before applying migrations, since the checking will be done as part of the migration
    #| process, before anything is applied.
    method check(--> Nil) {
        $!migration-list.build-schema($!database);
    }

    #| The result of applying an individual migration.
    class AppliedMigration {
        has Str $.description is required;
        has Str $.sql is required;
    }

    #| The result of applying migrations as requested.
    class MigrationOutcome {
        #| The direction of the migration.
        has MigrationDirection $.direction is required;

        #| The migrations that were applied.
        has AppliedMigration @.migrations is required;
    }

    #| Migrate the database to the latest version.
    method to-latest(--> MigrationOutcome) {
        # Ensure we have the database set up.
        try {
            $!database.ensure-migration-state-storage($!connection);
            CATCH {
                default {
                    die "Failed to set up migration storage state in the database: $_";
                }
            }
        }

        # Do the migration transitionally.
        my @applied;
        $!database.run-in-transaction: $!connection, -> $transaction {
            # Load the existing migration history, and follow it according to the current
            # specification, dividing the migration specification into past and future.
            my $db-history = $!database.load-migration-history($transaction, $!schema-id);
            my @past;
            my @future = $!migration-list.migrations;
            for $db-history.entries -> DB::Migration::Declare::MigrationHistory::Entry $entry {
                if $entry.direction == MigrationDirection::Up {
                    my DB::Migraion::Declare::Model::Migration $expected = @future[0];
                    my $expected-hash = $expected.hashed;
                    if $expected-hash eq $entry.hash {
                        @past.push: @future.shift;
                    }
                    else {
                        die X::DB::Migration::Declare::InconsistentHistory.new:
                                version => $entry.version,
                                specification-hash => $expected-hash,
                                specification-description => $expected.description,
                                specification-file => $expected.file,
                                specification-line => $expected.line,
                                stored-hash => $entry.hash,
                                stored-description => $entry.description;
                    }
                }
                else {
                    !!! "Downward migration is not yet implemented"
                }
            }

            # Generate SQL for each future migration to apply.
            my $schema = DB::Migration::Declare::Schema.new(target-database => $!database);
            my @to-apply;
            my @generated-sql;
            for @past -> DB::Migraion::Declare::Model::Migration $migration {
                $migration.apply-to($schema);
            }
            for @future -> DB::Migraion::Declare::Model::Migration $migration {
                @to-apply.push($migration);
                @generated-sql.push($migration.generate-up-sql($schema));
            }

            # Now do the application of the migrations.
            my $current-version = $db-history.entries ?? $db-history.entries[*- 1].version !! 0;
            for flat @to-apply Z @generated-sql -> $migration, $sql {
                $!database.apply-migration-sql($transaction, $sql);
                $!database.add-migration-history-entry($transaction, $!schema-id, ++$current-version, $migration.hashed,
                        MigrationDirection::Up, $migration.description);
                @applied.push: AppliedMigration.new: :description($migration.description), :$sql;
            }
        }
        return MigrationOutcome.new(migrations => @applied, direction => Up);
    }
}
