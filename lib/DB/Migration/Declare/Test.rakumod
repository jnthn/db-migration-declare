use v6.d;
use DB::Migration::Declare::Database;
use DB::Migration::Declare::Model;
use Test;

sub check-migrations(IO::Path :$source!, DB::Migration::Declare::Database :$database! --> Nil) is export {
    # Obtain migration files to load, in order.
    my @files = do if $source.f {
        $source
    }
    elsif $source.d {
        $source.dir(test => *.f).sort(~*)
    }
    else {
        die "Could not find a migration file or directory at '$source'";
    }

    # Load them and add them to the migration list.
    my $migration-list = DB::Migraion::Declare::Model::MigrationList.new;
    for @files {
        my $*DMD-MIGRATION-LIST = $migration-list;
        EVALFILE $_;
    }

    # Go through the migration list, building up a schema, and report any errors.
    my $schema = DB::Migration::Declare::Schema.new(target-database => $database);
    for $migration-list.migrations -> DB::Migraion::Declare::Model::Migration $migration {
        $migration.apply-to($schema);
        pass $migration.description;
        CATCH {
            when X::DB::Migration::Declare::MigrationProblem {
                flunk $migration.description;
                diag "Migration at {.migration-file}:{.migration-line} has problems:";
                for .problems {
                    diag .message.indent(2);
                }
            }
        }
    }
}
