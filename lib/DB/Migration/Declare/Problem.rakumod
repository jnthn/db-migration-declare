use DB::Migration::Declare::ColumnType;

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

#| An attempt to rename a table to a name that already exists.
class DB::Migration::Declare::Problem::TableRenameConflict does DB::Migration::Declare::Problem {
    #| The current table name.
    has Str $.from is required;

    #| The conflicting new table name.
    has Str $.to is required;

    method message(--> Str) {
        $!from eq $!to
                ?? "Rename of table '$!from' specifies the same from and to name"
                !! "Cannot rename table '$!from' to '$!to' because there is another table with that name"
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
        "Cannot $!action non-existent column '$!name' of table '$!table'"
    }
}

#| An attempt to rename a column to a name that already exists.
class DB::Migration::Declare::Problem::ColumnRenameConflict does DB::Migration::Declare::Problem {
    #| The table name.
    has Str $.table is required;

    #| The current column name.
    has Str $.from is required;

    #| The conflicting new column name.
    has Str $.to is required;

    method message(--> Str) {
        $!from eq $!to
            ?? "Rename of column '$!from' in table '$!table' specifies the same from and to name"
            !! "Cannot rename '$!from' column in table '$!table' to '$!to' because the table already has such a column"
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

#| An attempt to give a table a duplicate foreign key.
class DB::Migration::Declare::Problem::DuplicateForeignKey does DB::Migration::Declare::Problem {
    #| The table name.
    has Str $.table is required;

    #| The columns.
    has @.columns;

    method message(--> Str) {
        "Table '$!table' already has a foreign key on @!columns.map({ "'$_'" }).join(', ')"
    }
}

#| An attempt to give a table a foreign key that references the exact same columns.
class DB::Migration::Declare::Problem::IdentityForeignKey does DB::Migration::Declare::Problem {
    #| The table name.
    has Str $.table is required;

    #| The columns.
    has @.columns;

    method message(--> Str) {
        "Foreign key on '$!table' is on columns @!columns.map({ "'$_'" }).join(', ') but references exactly the same columns"
    }
}

#| An attempt to use a SQL construct unsupported by the target database.
class DB::Migration::Declare::Problem::UnsupportedSQL does DB::Migration::Declare::Problem {
    #| The database system that doesn't support the requested functionality.
    has Str $.database-name is required;

    #| The problem.
    has Str $.problem is required;

    method message(--> Str) {
        "$!problem for database $!database-name"
    }
}

#| An attempt to use a type unsupported by the target database.
class DB::Migration::Declare::Problem::UnsupportedType does DB::Migration::Declare::Problem {
    #| The database system that doesn't support the requested type.
    has Str $.database-name is required;

    #| The type that is not supported.
    has DB::Migration::Declare::ColumnType $.type is required;

    method message(--> Str) {
        "Type '$!type.describe()' is not supported by database $!database-name"
    }
}

#| Use of a type with :increments that does not support being auto-increment.
class DB::Migration::Declare::Problem::NotAnIncrementableType does DB::Migration::Declare::Problem {
    #| The table name.
    has Str $.table is required;

    #| The column name.
    has Str $.name is required;

    #| The type that is not supported.
    has DB::Migration::Declare::ColumnType $.type is required;

    method message(--> Str) {
        "Column '$!name' in table '$!table' is declared to auto-increment, but that is not possible with type '$!type.describe()'"
    }
}

#| Exception thrown where there is a problem with a migration.
class X::DB::Migration::Declare::MigrationProblem is Exception {
    #| The description of the migration with a problem.
    has Str $.migration-description is required;

    #| The file where the migration was declared.
    has Str $.migration-file is required;

    #| The line number where the migration was declared.
    has Int $.migration-line is required;

    #| The problems with the migration.
    has DB::Migration::Declare::Problem @.problems is required;

    method message(--> Str) {
        "The migration '$!migration-description' at $!migration-file:$!migration-line has problems:\n" ~
            @!problems.map({ '  ' ~ .message }).join("\n")
    }
}
