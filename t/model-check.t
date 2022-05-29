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

lives-ok
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                }
                migration 'No more customers', {
                    drop-table 'customers';
                }
                migration 'New customers', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                }
            }
        },
        'Cam create a table agian if an earlier migration dropped it';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                }
                migration 'Drop products', {
                    drop-table 'products';
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Drop products',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::NoSuchTable &&
                    .[0].name eq 'products' &&
                    .[0].action eq 'drop'
        },
        'Cannot drop a table that never existed';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                }
                migration 'Drop customers', {
                    drop-table 'customers';
                }
                migration 'Drop customers again', {
                    drop-table 'customers';
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Drop customers again',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::NoSuchTable &&
                    .[0].name eq 'customers' &&
                    .[0].action eq 'drop'
        },
        'Cannot drop the same table twice';

done-testing;
