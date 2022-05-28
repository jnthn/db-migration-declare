use Test;
use DB::Migration::Declare;
use DB::Migration::Declare::Model;
use DB::Migration::Declare::Problem;

sub check(&migrations) {
    my $*DMD-MIGRATION-LIST = DB::Migraion::Declare::Model::MigrationList.new;
    migrations();
    $*DMD-MIGRATION-LIST.build-schema();
}

lives-ok
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                    create-table 'products', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                }
            }
        },
        'Simple migration adding two tables is fine';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Setup',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::DuplicateTable &&
                    .[0].name eq 'customers'
        },
        'Duplicate table name within a migration';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                }
                migration 'Add products', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Add products',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::DuplicateTable &&
                    .[0].name eq 'customers'
        },
        'Duplicate table name accross migrations';

done-testing;
