use v6.d;
use DB::Migration::Declare::ColumnType;
use DB::Migration::Declare::Model::MigrationStep;
use DB::Migration::Declare::Problem;
use DB::Migration::Declare::Schema;
use DB::Migration::Declare::SQLLiteral;
use Digest::SHA1::Native;
unit module DB::Migraion::Declare::Model;

#| A step in a table creation.
role CreateTableStep {
    method hashable-str(--> Str) { ... }
}

#| A step in a table alteration.
role AlterTableStep {
    method hashable-str(--> Str) { ... }
}

#| A step that may appear in a table creation or alteration.
role CreateOrAlterTableStep does CreateTableStep does AlterTableStep {
    method !check-type(DB::Migration::Declare::Schema $schema, DB::Migration::Declare::ColumnType $type,
            @problems --> Nil) {
        without $schema.target-database.translate-type($type) {
            @problems.push: DB::Migration::Declare::Problem::UnsupportedType.new:
                    :database-name($schema.target-database.name), :$type
        }
    }
}

#| Adding a column.
class AddColumn does CreateOrAlterTableStep {
    has Str $.name is required;
    has DB::Migration::Declare::ColumnType $.type is required;
    has Bool $.null is required;
    has Bool $.increments is required;
    has Any $.default;

    method apply-to(DB::Migration::Declare::Schema $schema,
                    DB::Migration::Declare::Schema::Table $table,
                    @problems --> Nil) {
        if $table.has-column($!name) {
            @problems.push: DB::Migration::Declare::Problem::DuplicateColumn.new:
                    :table($table.name), :$!name;
        }
        else {
            $table.declare-column($!name);
            self!check-type($schema, $!type, @problems);
            if $!increments && !$schema.target-database.type-supports-increments($!type) {
                @problems.push: DB::Migration::Declare::Problem::NotAnIncrementableType.new:
                        :table($table.name), :$!name, :$!type;
            }
        }
    }

    method hashable-str(--> Str) {
        join "\0", "AddColumn", $!name, $!type.hashed, ($!null ?? 'null' !! 'not null'),
                ($!increments ?? 'increments' !! '')
    }
}

#| Renaming a column.
class RenameColumn does AlterTableStep {
    has Str $.from is required;
    has Str $.to is required;

    method apply-to(DB::Migration::Declare::Schema $schema,
                    DB::Migration::Declare::Schema::Table $table,
                    @problems --> Nil) {
        if $table.has-column($!from) {
            if $table.has-column($!to) {
                @problems.push: DB::Migration::Declare::Problem::ColumnRenameConflict.new:
                        :table($table.name), :$!from, :$!to;
            }
            else {
                $schema.rename-column($table, $!from, $!to);
            }
        }
        else {
            @problems.push: DB::Migration::Declare::Problem::NoSucColumn.new:
                    :table($table.name), :name($!from), :action('rename');
        }
    }

    method hashable-str(--> Str) {
        join "\0", "RenameColumn", $!from, $!to
    }
}

#| Dropping a column.
class DropColumn does AlterTableStep {
    has Str $.name is required;

    method apply-to(DB::Migration::Declare::Schema $schema,
                    DB::Migration::Declare::Schema::Table $table,
                    @problems --> Nil) {
        if $table.has-column($!name) {
            $table.remove-column($!name);
        }
        else {
            @problems.push: DB::Migration::Declare::Problem::NoSucColumn.new:
                    :table($table.name), :$!name, :action('drop');
        }
    }

    method hashable-str(--> Str) {
        join "\0", "DropColumn", $!name
    }
}

#| Specifying the primary key.
class PrimaryKey does CreateOrAlterTableStep {
    has Str @.column-names is required;

    method apply-to(DB::Migration::Declare::Schema $schema,
                    DB::Migration::Declare::Schema::Table $table,
                    @problems --> Nil) {
        if $table.has-primary-key {
            @problems.push: DB::Migration::Declare::Problem::MultiplePrimaryKeys.new(:name($table.name));
            return;
        }
        for @!column-names {
            unless $table.has-column($_) {
                @problems.push: DB::Migration::Declare::Problem::NoSucColumn.new:
                        :table($table.name), :name($_), :action('create a primary key with');
            }
        }
        $table.set-primary-key(@!column-names);
    }

    method hashable-str(--> Str) {
        join "\0", "PrimaryKey", @!column-names.sort
    }
}

#| Add a unique key.
class UniqueKey does CreateOrAlterTableStep {
    has Str @.column-names is required;

    method apply-to(DB::Migration::Declare::Schema $schema,
                    DB::Migration::Declare::Schema::Table $table,
                    @problems --> Nil) {
        if $table.has-unique-key(@!column-names) {
            @problems.push: DB::Migration::Declare::Problem::DuplicateUniqueKey.new:
                    :table($table.name), :columns(@!column-names);
        }
        for @!column-names {
            unless $table.has-column($_) {
                @problems.push: DB::Migration::Declare::Problem::NoSucColumn.new:
                        :table($table.name), :name($_), :action('create a unique key with');
            }
        }
        $table.add-unique-key(@!column-names);
    }

    method hashable-str(--> Str) {
        join "\0", "UniqueKey", @!column-names.sort
    }
}

#| Dropping a unique key.
class DropUniqueKey does AlterTableStep {
    has Str @.column-names is required;

    method apply-to(DB::Migration::Declare::Schema $schema,
                    DB::Migration::Declare::Schema::Table $table,
                    @problems --> Nil) {
        if $table.has-unique-key(@!column-names) {
            $table.drop-unique-key(@!column-names);
        }
        else {
            @problems.push: DB::Migration::Declare::Problem::NoSuchUniqueKey.new:
                    :table($table.name), :columns(@!column-names);
        }
    }

    method hashable-str(--> Str) {
        join "\0", "DropUniqueKey", @!column-names.sort
    }
}

#| Add a foreign key.
class ForeignKey does CreateOrAlterTableStep {
    has Str @.from is required;
    has Str $.table is required;
    has Str @.to is required;
    has Bool $.restrict = False;
    has Bool $.cascade = False;

    submethod TWEAK() {
        unless @!from.elems == @!to.elems {
            die "Number of columns must match in foreign key table '$!table'";
        }
        if $!restrict && $!cascade {
            die "Foreign key cannot both restrict and cascade";
        }
    }

    method apply-to(DB::Migration::Declare::Schema $schema,
                    DB::Migration::Declare::Schema::Table $table,
                    @problems --> Nil) {
        with $schema.table($!table) -> $target-table {
            for @!from -> Str $from {
                unless $table.has-column($from) {
                    @problems.push: DB::Migration::Declare::Problem::NoSucColumn.new:
                            :table($table.name), :name($from), :action('add a foreign key to');
                }
            }
            for @!to -> Str $to {
                unless $target-table.has-column($to) {
                    @problems.push: DB::Migration::Declare::Problem::NoSucColumn.new:
                            :table($target-table.name), :name($to), :action('have a foreign key referencing');
                }
            }
            if $table === $target-table && all @!to >>eq<< @!from {
                @problems.push: DB::Migration::Declare::Problem::IdentityForeignKey.new:
                        :table($table.name), :columns(@!from);
            }
            if $table.has-foreign-key-on(@!from) {
                @problems.push: DB::Migration::Declare::Problem::DuplicateForeignKey.new:
                        :table($table.name), :columns(@!from);
            }
            elsif !@problems {
                $table.add-foreign-key(@!from, $!table, @!to);
            }
        }
        else {
            @problems.push: DB::Migration::Declare::Problem::NoSuchTable.new:
                    :name($!table), :action('have a foreign key reference')
        }
    }

    method hashable-str(--> Str) {
        join "\0", "ForeignKey", $!table, @!from.map({ "F:$_" }), @!to.map({ "T:$_" }),
                ($!restrict ?? 'R' !! ''), ($!cascade ?? 'C' !! '')
    }
}

#| A table creation.
class CreateTable does DB::Migration::Declare::Model::MigrationStep {
    has Str $.name is required;
    has CreateTableStep @.steps;

    method add-step(CreateTableStep $step --> Nil) {
        @!steps.push($step);
    }

    method apply-to(DB::Migration::Declare::Schema $schema, @problems --> Nil) {
        if $schema.has-table($!name) {
            @problems.push: DB::Migration::Declare::Problem::DuplicateTable.new:
                    :$!name;
            return;
        }
        my $table = $schema.declare-table($!name);
        for @!steps {
            .apply-to($schema, $table, @problems);
        }
    }

    method hashed(--> Str) {
        sha1-hex(join "\0", "CreateTable", $!name, @!steps.map(*.hashable-str))
    }
}

#| A table alteration.
class AlterTable does DB::Migration::Declare::Model::MigrationStep {
    has Str $.name is required;
    has AlterTableStep @.steps;

    method add-step(AlterTableStep $step --> Nil) {
        @!steps.push($step);
    }

    method apply-to(DB::Migration::Declare::Schema $schema, @problems --> Nil) {
        with $schema.table($!name) -> $table {
            for @!steps {
                .apply-to($schema, $table, @problems);
            }
        }
        else {
            @problems.push: DB::Migration::Declare::Problem::NoSuchTable.new:
                    :action('alter'), :$!name;
        }
    }

    method hashed(--> Str) {
        sha1-hex(join "\0", "AlterTable", $!name, @!steps.map(*.hashable-str))
    }
}

#| A table rename.
class RenameTable does DB::Migration::Declare::Model::MigrationStep {
    has Str $.from is required;
    has Str $.to is required;

    method apply-to(DB::Migration::Declare::Schema $schema, @problems --> Nil) {
        if $schema.has-table($!from) {
            if $schema.has-table($!to) {
                @problems.push: DB::Migration::Declare::Problem::TableRenameConflict.new:
                        :$!from, :$!to;
            }
            else {
                $schema.rename-table($!from, $!to);
            }
        }
        else {
            @problems.push: DB::Migration::Declare::Problem::NoSuchTable.new:
                    :name($!from), :action('rename');
        }
    }

    method hashed(--> Str) {
        sha1-hex(join "\0", "RenameTable", $!from, $!to)
    }
}

#| A table drop.
class DropTable does DB::Migration::Declare::Model::MigrationStep {
    has Str $.name is required;

    method apply-to(DB::Migration::Declare::Schema $schema, @problems --> Nil) {
        if $schema.has-table($!name) {
            $schema.remove-table($!name);
        }
        else {
            @problems.push: DB::Migration::Declare::Problem::NoSuchTable.new:
                    :action('drop'), :$!name;
        }
    }

    method hashed(--> Str) {
        sha1-hex(join "\0", "DropTable", $!name)
    }
}

#| Execute the specified SQL query. Used as an escape hatch.
class ExecuteSQL does DB::Migration::Declare::Model::MigrationStep {
    has DB::Migration::Declare::SQLLiteral $.up is required;
    has DB::Migration::Declare::SQLLiteral $.down is required;

    method apply-to(DB::Migration::Declare::Schema $schema, @problems --> Nil) {
        .get-sql(database => $schema.target-database) for $!up, $!down;
        CATCH {
            default {
                @problems.push: DB::Migration::Declare::Problem::UnsupportedSQL.new:
                        database-name => $schema.target-database.name, problem => .message;
            }
        }
    }

    method hashed(--> Str) {
        sha1-hex(join "\0", "ExecuteSQL", $!up.hashed, $!down.hashed)
    }
}

#| A migration, consisting of a step of steps.
class Migration {
    has Str $.file is required;
    has Int $.line is required;
    has Str $.description is required;
    has DB::Migration::Declare::Model::MigrationStep @!steps;

    #| Add a step to the migration.
    method add-step(DB::Migration::Declare::Model::MigrationStep $step --> Nil) {
        @!steps.push($step);
    }

    #| Apply the migration steps to the specified schema, but don't do any SQL generation.
    method apply-to(DB::Migration::Declare::Schema $schema --> Nil) {
        my @problems;
        for @!steps {
            .apply-to($schema, @problems);
        }
        self!report-problems(@problems);
    }

    #| Get a unique hash for the migration.
    method hashed(--> Str) {
        sha1-hex @!steps.map(*.hashed).join("\n")
    }

    #| Generate the SQL to raise the database to the specified migration, also applying
    #| the changes to the passed in schema object. The schema should be in the state of
    #| having had all previous migrations have been applied, in order that any code
    #| generation that is interested in the current state can do that.
    method generate-up-sql(DB::Migration::Declare::Schema $schema, Any $connection --> Str) {
        my @sql-parts;
        my @problems;
        for @!steps {
            @sql-parts.push: $schema.target-database.translate-up($_, :$schema, :$connection);
            .apply-to($schema, @problems);
        }
        self!report-problems(@problems);
        @sql-parts.join()
    }

    method !report-problems(@problems --> Nil) {
        if @problems {
            die X::DB::Migration::Declare::MigrationProblem.new:
                    :@problems, :migration-description($!description),
                    :migration-file($!file), :migration-line($!line);
        }
    }
}

#| A list of migrations to be applied in order.
class MigrationList {
    has Migration @.migrations;

    method add-migration(Migration $migration --> Nil) {
        @!migrations.push($migration);
    }

    method build-schema(DB::Migration::Declare::Database $target-database --> DB::Migration::Declare::Schema) {
        my $schema = DB::Migration::Declare::Schema.new(:$target-database);
        for @!migrations {
            .apply-to($schema);
        }
        $schema
    }
}