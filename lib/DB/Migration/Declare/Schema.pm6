use DB::Migration::Declare::Database;

#| A database schema built up from a number of migrations. Used to validate
#| migrations and to examine the final state of the database after all of the
#| migrations are applied.
class DB::Migration::Declare::Schema {
    #| A column in a table.
    class Column {
        #| The name of the column.
        has Str $.name;
    }

    #| A foreign key.
    class ForeignKey {
        #| This table's columns.
        has Str @.from;

        #| The target table.
        has Str $.table;

        #| The target table's columns.
        has Str @.to;
    }

    #| A table in the database.
    class Table {
        #| The name of the table.
        has Str $.name;

        #| The columns, in order.
        has Column @!columns;

        #| Lookup of the columns by name.
        has Int %!column-lookup;

        #| The column(s) making up the primary key, if any.
        has Str @!primary-key-columns;

        #| Lists of columns making up unique keys.
        has List @!unique-key-sets;

        #| Foreign keys.
        has ForeignKey @!foreign-keys;

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

        #| Set the primary key.
        method set-primary-key(@columns --> Nil) {
            @!primary-key-columns = @columns;
        }

        #| Check if the table has a primary key.
        method has-primary-key(--> Bool) {
            ?@!primary-key-columns
        }

        #| Add a unique key column set.
        method add-unique-key(@columns --> Nil) {
            @!unique-key-sets.push(@columns.List);
        }

        #| Check if the table has a given unique key.
        method has-unique-key(@columns --> Bool) {
            my \sorted = @columns.sort.List;
            ?@!unique-key-sets.map(*.sort.List).first(sorted)
        }

        #| Add a foreign key.
        method add-foreign-key(@from, Str $table, @to --> Nil) {
            @!foreign-keys.push(ForeignKey.new(:@from, :$table, :@to));
        }

        #| Check if the table has a foreign key on the given columns.
        method has-foreign-key-on(@from --> Bool) {
            my \sorted = @from.sort.List;
            ?@!foreign-keys.map(*.from.sort.List).first(sorted)
        }
    }

    #| The database this schema is aimed at.
    has DB::Migration::Declare::Database $.target-database is required;

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
