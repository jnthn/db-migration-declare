#| The base of all problems.
role DB::Migration::Declare::Problem {
    method message(--> Str) { ... }
}

#| Duplicate creation of the same table.
class DB::Migration::Declare::Problem::DuplicateTable does DB::Migration::Declare::Problem {
    #| The table name.
    has Str $.name is required;

    method message(--> Str) {
        "The table '$!name' already exists in the database"
    }
}

#| An action involving a table that does not exist.
class DB::Migration::Declare::Problem::NoSuchTable does DB::Migration::Declare::Problem {
    #| The table name.
    has Str $.name is required;

    #| The action we were trying to perform.
    has Str $.action is required;

    method message(--> Str) {
        "Cannot $!action non-existent table '$!name'"
    }
}

#| Duplicate creation of the same column.
class DB::Migration::Declare::Problem::DuplicateColumn does DB::Migration::Declare::Problem {
    #| The table name.
    has Str $.table is required;

    #| The column name.
    has Str $.name is required;

    method message(--> Str) {
        "The column '$!name' already exists in the table '$!table'"
    }
}

#| An action involving a column that does not exist.
class DB::Migration::Declare::Problem::NoSucColumn does DB::Migration::Declare::Problem {
    #| The table name.
    has Str $.table is required;

    #| The column name.
    has Str $.name is required;

    #| The action we were trying to perform.
    has Str $.action is required;

    method message(--> Str) {
        "Cannot $!action non-existent columnb '$!name' of table '$!table'"
    }
}

#| An attempt to give a table more than one primary key.
class DB::Migration::Declare::Problem::MultiplePrimaryKeys does DB::Migration::Declare::Problem {
    #| The table name.
    has Str $.name is required;

    method message(--> Str) {
        "Table '$!name' already has a primary key"
    }
}

#| An attempt to give a table a duplicate unique key.
class DB::Migration::Declare::Problem::DuplicateUniqueKey does DB::Migration::Declare::Problem {
    #| The table name.
    has Str $.table is required;

    #| The columns.
    has @.columns;

    method message(--> Str) {
        "Table '$!table' already has a unique key on @!columns.map({ "'$_'" }).join(', ')"
    }
}

class X::DB::Migration::Declare::MigrationProblem is Exception {
    #| The description of the migration with a problem.
    has Str $.migration-description is required;

    #| The file where the migration was declared.
    has Str $.migration-file is required;

    #| The line number where the migration was declared.
    has Int $.migration-line is required;

    #| The problems with the migration.
    has DB::Migration::Declare::Problem @.problems is required;
}
