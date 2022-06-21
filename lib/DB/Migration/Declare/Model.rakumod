use v6.d;
use DB::Migration::Declare::ColumnType;
use DB::Migration::Declare::Problem;
use DB::Migration::Declare::Schema;
unit module DB::Migraion::Declare::Model;

#| A step in a migration.
role MigrationStep {
}

#| A step in a table creation.
role CreateTableStep {
}

#| A step in a table alteration.
role AlterTableStep {
}

#| A step that may appear in a table creation or alteration.
role CreateOrAlterTableStep does CreateTableStep does AlterTableStep {
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
        }
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
}

#| A table creation.
class CreateTable is MigrationStep {
    has Str $.name is required;
    has CreateTableStep @!steps;

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
}

#| A table alteration.
class AlterTable is MigrationStep {
    has Str $.name is required;
    has AlterTableStep @!steps;

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
}

#| A table drop.
class DropTable is MigrationStep {
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
}

#| A migration, consisting of a step of steps.
class Migration {
    has Str $.file is required;
    has Int $.line is required;
    has Str $.description is required;
    has MigrationStep @!steps;

    method add-step(MigrationStep $step --> Nil) {
        @!steps.push($step);
    }

    method apply-to(DB::Migration::Declare::Schema $schema --> Nil) {
        my @problems;
        for @!steps {
            .apply-to($schema, @problems);
        }
        if @problems {
            die X::DB::Migration::Declare::MigrationProblem.new:
                    :@problems, :migration-description($!description),
                    :migration-file($!file), :migration-line($!line);
        }
    }
}

#| A list of migrations to be applied in order.
class MigrationList {
    has Migration @!migrations;

    method add-migration(Migration $migration --> Nil) {
        @!migrations.push($migration);
    }

    method build-schema(--> DB::Migration::Declare::Schema) {
        my $schema = DB::Migration::Declare::Schema.new;
        for @!migrations {
            .apply-to($schema);
        }
        $schema
    }
}