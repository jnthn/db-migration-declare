#| A database schema built up from a number of migrations. Used to validate
#| migrations and to examine the final state of the database after all of the
#| migrations are applied.
class DB::Migration::Declare::Schema {
    #| A column in a table.
    class Column {
        #| The name of the column.
        has Str $.name;
    }

    #| A table in the database.
    class Table {
        #| The name of the table.
        has Str $.name;

        #| The columns, in order.
        has Column @!columns;

        #| Lookup of the columns by name.
        has Int %!column-lookup;

        #| Get the columns that are part of this table.
        method columns() {
            @!columns.List
        }

        #| Checks if a column exists.
        method has-column(Str $name --> Bool) {
            %!column-lookup{$name}:exists
        }

        #| Look up a column by name.
        method column(Str $name --> Column) {
            @!columns[%!column-lookup{$name}] // fail "No such column '$name'"
        }

        #| Declare a new column in the table.
        method declare-column(Str $name --> Column) {
            fail "Column '$name' already in schema" if %!column-lookup{$name}:exists;
            my $column = Column.new(:$name);
            @!columns.push($column);
            %!column-lookup{$name} = @!columns.end;
            return $column;
        }

        #| Remove a column.
        method remove-column(Str $name --> Nil) {
            my $index = %!column-lookup{$name}:delete // fail "No such column '$name'";
            @!columns.splice($index, 1);
        }
    }

    #| Lookup of the tables, keyed on name.
    has Table %!tables;

    #| Get the tables that are part of this schema.
    method tables() {
        %!tables.values
    }

    #| Check if the schema has a table.
    method has-table(Str $name --> Bool) {
        %!tables{$name}:exists
    }

    #| Look up a table by name.
    method table(Str $name --> Table) {
        %!tables{$name} // fail "No such table '$name'"
    }

    #| Declare a table.
    method declare-table(Str $name --> Table) {
        fail "Table '$name' already in schema" if %!tables{$name}:exists;
        my $table = Table.new(:$name);
        %!tables{$name} = $table;
        $table
    }

    #| Remove a table.
    method remove-table(Str $name --> Nil) {
        %!tables{$name}:delete // fail "No such table '$name'";
    }
}
