use v6.d;
use DB::Migration::Declare::Database;
use DB::Migration::Declare::Model;
use DB::Migration::Declare::Schema;

#| Loads migrations and applies them to a target database.
class DB::Migration::Declare::Applicator {
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

    #| The direction of a migration.
    enum MigrationDirection <Up Down>;

    #| The result of applying migrations as requested.
    class MigrationOutcome {
        #| The direction of the migration.
        has MigrationDirection $.direction is required;

        #| The migrations that were applied.
        has AppliedMigration @.migrations is required;
    }

    #| Migrate the database to the latest version.
    method to-latest(--> MigrationOutcome) {
        # TODO Actually track applied versions. For now just apply them all.
        # Generate SQL for each migration.
        my $schema = DB::Migration::Declare::Schema.new(target-database => $!database);
        my @to-apply;
        my @generated-sql;
        for $!migration-list.migrations -> DB::Migraion::Declare::Model::Migration $migration {
            @to-apply.push($migration);
            @generated-sql.push($migration.generate-up-sql($schema));
        }

        # Now do the application of the migrations.
        my @applied;
        for flat @to-apply Z @generated-sql -> $migration, $sql {
            $!database.apply-migration-sql($!connection, $sql);
            @applied.push: AppliedMigration.new: :description($migration.description), :$sql;
        }
        return MigrationOutcome.new(migrations => @applied, direction => Up);
    }
}
