use v6.d;

#| The base of all column types.
role DB::Migration::Declare::ColumnType {
    method describe(--> Str) { ... }
}

#| A simple named type, which we may request is not checked against those known to us as
#| valid database types in the chosen backend.
class DB::Migration::Declare::ColumnType::Named does DB::Migration::Declare::ColumnType {
    has Str $.name is required;
    has Bool $.checked = True;
    method describe(--> Str) { $!name }
}

#| A character type column, char or varchar, with a length.
class DB::Migration::Declare::ColumnType::Char does DB::Migration::Declare::ColumnType {
    has Int $.length is required;
    has Bool $.varying is required;
    method describe(--> Str) { ($!varying ?? 'varchar' !! 'char') ~ ($!length ?? "($!length)" !! "")  }
}

#| A text type column.
class DB::Migration::Declare::ColumnType::Text does DB::Migration::Declare::ColumnType {
    method describe(--> Str) { 'text' }
}

#| A boolean type column.
class DB::Migration::Declare::ColumnType::Boolean does DB::Migration::Declare::ColumnType {
    method describe(--> Str) { 'boolean' }
}

#| An integer type column of the specified number of bytes.
class DB::Migration::Declare::ColumnType::Integer does DB::Migration::Declare::ColumnType {
    has Int $.bytes is required;
    method describe(--> Str) { "integer$!bytes" }
}

#| A date (without time) column.
class DB::Migration::Declare::ColumnType::Date does DB::Migration::Declare::ColumnType {
    method describe(--> Str) { 'date' }
}

#| A timestamp (date and time) column, optionally with a timezone.
class DB::Migration::Declare::ColumnType::Timestamp does DB::Migration::Declare::ColumnType {
    has Bool $.timezone = False;
    method describe(--> Str) { 'timestamp' }
}

#| An array column type.
class DB::Migration::Declare::ColumnType::Array does DB::Migration::Declare::ColumnType {
    has DB::Migration::Declare::ColumnType $.element-type is required;
    has @.dimensions = *;
    method describe(--> Str) { $!element-type.describe ~ @!dimensions.map({ .isa(Whatever) ?? '[]' !! "[$_]"  }) }
}