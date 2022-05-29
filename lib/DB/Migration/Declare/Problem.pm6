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
        "Cannot $!action non-existant table '$!name'"
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
