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
}

#| Dropping a column.
class DropColumn does AlterTableStep {
    has Str $.name is required;
}

#| Specifying the primary key.
class PrimaryKey does CreateOrAlterTableStep {
    has Str @.column-names is required;
}

#| Add a unique key.
class UniqueKey does CreateOrAlterTableStep {
    has Str @.column-names is required;
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
    }
}

#| A table alteration.
class AlterTable is MigrationStep {
    has Str $.name is required;
    has CreateTableStep @!steps;

    method add-step(AlterTableStep $step --> Nil) {
        @!steps.push($step);
    }
}

#| A table drop.
class DropTable is MigrationStep {
    has Str $.name is required;
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