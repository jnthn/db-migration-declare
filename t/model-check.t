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

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                        add-column 'name', text(), :!null;
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Setup',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::DuplicateColumn &&
                    .[0].table eq 'customers' &&
                    .[0].name eq 'name'
        },
        'Duplicate column in initial table creationn';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                }
                migration 'Add country', {
                    alter-table 'customers', {
                        add-column 'name', text(), :!null;
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Add country',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::DuplicateColumn &&
                    .[0].table eq 'customers' &&
                    .[0].name eq 'name'
        },
        'Duplicate column added when altering table';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                }
                migration 'Add country', {
                    alter-table 'customer', {
                        add-column 'country', text(), :!null;
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Add country',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::NoSuchTable &&
                    .[0].name eq 'customer' &&
                    .[0].action eq 'alter'
        },
        'Cannot alter non-existent table';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                }
                migration 'Drop country', {
                    alter-table 'customers', {
                        drop-column 'country';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Drop country',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::NoSucColumn &&
                    .[0].table eq 'customers' &&
                    .[0].name eq 'country' &&
                    .[0].action eq 'drop'
        },
        'Dropping column that never existed';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                        add-column 'country', text(), :!null;
                    }
                }
                migration 'Drop country', {
                    alter-table 'customers', {
                        drop-column 'country';
                    }
                }
                migration 'Drop name', {
                    alter-table 'customers', {
                        drop-column 'country';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Drop name',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::NoSucColumn &&
                    .[0].table eq 'customers' &&
                    .[0].name eq 'country' &&
                    .[0].action eq 'drop'
        },
        'Dropping column that was already dropped';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments;
                        add-column 'name', text(), :!null;
                        primary-key 'email';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Setup',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::NoSucColumn &&
                    .[0].table eq 'customers' &&
                    .[0].name eq 'email' &&
                    .[0].action eq 'create a primary key with'
        },
        'Adding primary key on a column that never existed';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments;
                        add-column 'name', text(), :!null;
                        primary-key 'id';
                        primary-key 'name';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Setup',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::MultiplePrimaryKeys &&
                    .[0].name eq 'customers'
        },
        'Multiple primary keys within initial creation';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                }
                migration 'Add email', {
                    alter-table 'customers', {
                        add-column 'email', text(), :!null;
                        primary-key 'email';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Add email',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::MultiplePrimaryKeys &&
                    .[0].name eq 'customers'
        },
        'Trying to add duplicate primary key in alteration';

lives-ok
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'name', text(), :!null;
                    }
                }
                migration 'Add email', {
                    alter-table 'customers', {
                        add-column 'email', text(), :!null;
                        primary-key 'email';
                    }
                }
            }
        },
        'Can add a primary ken in an alteration to a table without one';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                        unique-key 'email';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Setup',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::NoSucColumn &&
                    .[0].table eq 'customers' &&
                    .[0].name eq 'email' &&
                    .[0].action eq 'create a unique key with'
        },
        'Adding unique key on a column that never existed';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                        unique-key 'email';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Setup',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::NoSucColumn &&
                    .[0].table eq 'customers' &&
                    .[0].name eq 'email' &&
                    .[0].action eq 'create a unique key with'
        },
        'Adding unique key on a column that never existed';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                        add-column 'email', text(), :!null;
                        unique-key 'email';
                        unique-key 'email';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Setup',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::DuplicateUniqueKey &&
                    .[0].table eq 'customers' &&
                    .[0].columns eqv ['email',]
        },
        'Adding duplicate unique key within create table';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'email', text(), :!null;
                        unique-key 'email';
                    }
                }
                migration 'Add company number', {
                    alter-table 'customers', {
                        add-column 'company', text(), :!null;
                        unique-key 'email';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Add company number',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::DuplicateUniqueKey &&
                    .[0].table eq 'customers' &&
                    .[0].columns eqv ['email',]
        },
        'Adding duplicate unique key in alter table';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'email', text(), :!null;
                        add-column 'company', text(), :!null;
                        unique-key 'email', 'company';
                    }
                }
                migration 'Add index', {
                    alter-table 'customers', {
                        unique-key 'company', 'email';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Add index',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::DuplicateUniqueKey &&
                    .[0].table eq 'customers' &&
                    .[0].columns eqv ['company','email']
        },
        'Duplication of composite unique key detected even with differnt order';

lives-ok
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'email', text(), :!null;
                        unique-key 'email';
                    }
                }
                migration 'Add company', {
                    alter-table 'customers', {
                        add-column 'company', text(), :!null;
                        unique-key 'company', 'email';
                    }
                }
            }
        },
        'Composite unique key OK even if unique key on another column';

done-testing;
