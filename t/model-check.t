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
        'Can add a primary key in an alteration to a table without one';

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

lives-ok
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'email', text(), :!null;
                        unique-key 'email';
                    }
                    create-table 'projects', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'customer', integer(), :!null;
                        add-column 'title', text(), :!null;
                        foriegn-key from => 'customer', to => 'id', table => 'customers';
                    }
                }
            }
        },
        'Can create a foreign key referring to a table created in this migration step';

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
                migration 'Add projects', {
                    create-table 'projects', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'customer', integer(), :!null;
                        add-column 'title', text(), :!null;
                        foriegn-key from => 'customer', to => 'id', table => 'customers';
                    }
                }
            }
        },
        'Can create a foreign key referring to a table created in an earlier migration step';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'email', text(), :!null;
                        unique-key 'email';
                    }
                    create-table 'projects', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'customer', integer(), :!null;
                        add-column 'title', text(), :!null;
                        foriegn-key from => 'customer', to => 'id', table => 'customer';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Setup',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::NoSuchTable &&
                    .[0].name eq 'customer' &&
                    .[0].action eq 'have a foreign key reference'
        },
        'Cannot have a foreign key referencing a table that does not exist';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'email', text(), :!null;
                        unique-key 'email';
                    }
                    create-table 'projects', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'customer', integer(), :!null;
                        add-column 'title', text(), :!null;
                        foriegn-key from => 'customers', to => 'id', table => 'customers';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Setup',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::NoSucColumn &&
                    .[0].table eq 'projects' &&
                    .[0].name eq 'customers' &&
                    .[0].action eq 'add a foreign key to'
        },
        'Cannot have a foreign key from a column that does not exist';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'email', text(), :!null;
                        unique-key 'email';
                    }
                    create-table 'projects', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'customer', integer(), :!null;
                        add-column 'title', text(), :!null;
                        foriegn-key from => 'customer', to => 'di', table => 'customers';
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
                    .[0].name eq 'di' &&
                    .[0].action eq 'have a foreign key referencing'
        },
        'Cannot have a foreign key to a column that does not exist';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'email', text(), :!null;
                        unique-key 'email';
                    }
                    create-table 'products', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                    create-table 'projects', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'customer', integer(), :!null;
                        add-column 'title', text(), :!null;
                        add-column 'product', text(), :!null;
                        foriegn-key from => 'customer', to => 'id', table => 'customers';
                        foriegn-key from => 'customer', to => 'id', table => 'products';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Setup',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::DuplicateForeignKey &&
                    .[0].table eq 'projects' &&
                    .[0].columns eqv ['customer']
        },
        'Cannot have two foreign keys on one source column';

lives-ok
        {
            check {
                migration 'Setup', {
                    create-table 'employees', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                        add-column 'manager', integer();
                        foriegn-key from => 'manager', table => 'employees', to => 'id'
                    }
                }
            }
        },
        'Foreign key within table is OK';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'employees', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                        add-column 'manager', integer();
                        foriegn-key from => 'manager', table => 'employees', to => 'manager'
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Setup',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::IdentityForeignKey &&
                    .[0].table eq 'employees' &&
                    .[0].columns eqv ['manager']
        },
        'Cannot have a foreign key pointing to the same column';

lives-ok
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'region', integer(), :!null;
                        add-column 'name', varchar(64), :!null;
                        unique-key 'region', 'name';
                    }
                }
                migration 'Add projects', {
                    create-table 'projects', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'customer_region', integer(), :!null;
                        add-column 'customer_name', varchar(64), :!null;
                        add-column 'title', text(), :!null;
                        foriegn-key from => ['customer_region', 'customer_name'], to => ['region', 'name'], table => 'customers';
                    }
                }
            }
        },
        'Composite foreign keys are handled fine';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'region', integer(), :!null;
                        add-column 'name', varchar(64), :!null;
                        unique-key 'region', 'name';
                    }
                }
                migration 'Add projects', {
                    create-table 'projects', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'customer_region', integer(), :!null;
                        add-column 'customer_name', varchar(64), :!null;
                        add-column 'title', text(), :!null;
                        foriegn-key from => ['customer_region', 'customer_name'], to => ['region', 'name'], table => 'customurs';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Add projects',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::NoSuchTable &&
                    .[0].name eq 'customurs' &&
                    .[0].action eq 'have a foreign key reference'
        },
        'Cannot have a foreign key referencing a table that does not exist (composite)';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'region', integer(), :!null;
                        add-column 'name', varchar(64), :!null;
                        unique-key 'region', 'name';
                    }
                }
                migration 'Add projects', {
                    create-table 'projects', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'customer_region', integer(), :!null;
                        add-column 'customer_name', varchar(64), :!null;
                        add-column 'title', text(), :!null;
                        foriegn-key from => ['customer_region', 'custom_name'], to => ['region', 'name'], table => 'customers';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Add projects',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::NoSucColumn &&
                    .[0].table eq 'projects' &&
                    .[0].name eq 'custom_name' &&
                    .[0].action eq 'add a foreign key to'
        },
        'Cannot have a foreign key from a column that does not exist (composite)';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'region', integer(), :!null;
                        add-column 'name', varchar(64), :!null;
                        unique-key 'region', 'name';
                    }
                }
                migration 'Add projects', {
                    create-table 'projects', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'customer_region', integer(), :!null;
                        add-column 'customer_name', varchar(64), :!null;
                        add-column 'title', text(), :!null;
                        foriegn-key from => ['customer_region', 'customer_name'], to => ['region', 'namen'], table => 'customers';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Add projects',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::NoSucColumn &&
                    .[0].table eq 'customers' &&
                    .[0].name eq 'namen' &&
                    .[0].action eq 'have a foreign key referencing'
        },
        'Cannot have a foreign key to a column that does not exist (composite)';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'region', integer(), :!null;
                        add-column 'name', varchar(64), :!null;
                        unique-key 'region', 'name';
                    }
                }
                migration 'Add projects', {
                    create-table 'projects', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'customer_region', integer(), :!null;
                        add-column 'customer_name', varchar(64), :!null;
                        add-column 'title', text(), :!null;
                        foriegn-key from => ['customer_region', 'customer_name'], to => ['region', 'name'], table => 'customers';
                        foriegn-key from => ['customer_name', 'customer_region'], to => ['name', 'region'], table => 'customers';
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Add projects',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::DuplicateForeignKey &&
                    .[0].table eq 'projects' &&
                    .[0].columns.sort eqv ['customer_name', 'customer_region'].sort
        },
        'Cannot have two foreign keys on the same source column tuple';

lives-ok
        {
            check {
                migration 'Setup', {
                    create-table 'employees', {
                        add-column 'ssid', integer(), :!null, :primary;
                        add-column 'country', char(2), :!null, :primary;
                        add-column 'name', text(), :!null;
                        add-column 'manager_ssid', integer();
                        add-column 'manager_country', integer();
                        foriegn-key from => ['manager_ssid', 'manager_country'], table => 'employees', to => ['ssid', 'country']
                    }
                }
            }
        },
        'Composite foreign key within table is OK';

throws-like
        {
            check {
                migration 'Setup', {
                    create-table 'employees', {
                        add-column 'ssid', integer(), :!null, :primary;
                        add-column 'country', char(2), :!null, :primary;
                        add-column 'name', text(), :!null;
                        add-column 'manager_ssid', integer();
                        add-column 'manager_country', integer();
                        foriegn-key from => ['manager_ssid', 'manager_country'], table => 'employees', to => ['manager_ssid', 'manager_country']
                    }
                }
            }
        },
        X::DB::Migration::Declare::MigrationProblem,
        migration-description => 'Setup',
        problems => {
            .elems == 1 &&
                    .[0] ~~ DB::Migration::Declare::Problem::IdentityForeignKey &&
                    .[0].table eq 'employees' &&
                    .[0].columns eqv ['manager_ssid', 'manager_country']
        },
        'Cannot have a composite foreign key pointing to the same columns';

lives-ok
        {
            check {
                migration 'Setup', {
                    create-table 'customers', {
                        add-column 'id', integer(), :increments, :primary;
                        add-column 'name', text(), :!null;
                    }
                    execute sql postgres => "INSERT INTO customers (name) VALUES ('Fred')";
                }
            }
        },
        'Model with custom SQL execution is fine';

done-testing;
