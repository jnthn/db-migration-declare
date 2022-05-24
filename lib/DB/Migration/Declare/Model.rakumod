use v6.d;
use DB::Migration::Declare::ColumnType;
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
    has Str $.description is required;
    has MigrationStep @!steps;

    method add-step(MigrationStep $step --> Nil) {
        @!steps.push($step);
    }
}
