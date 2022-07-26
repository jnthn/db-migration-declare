use v6.d;
use DB::Migration::Declare::Database;
use DB::Migration::Declare::Model;

my constant TYPES = set <
    bigint	int8
    bit
    boolean	bool
    box
    bytea
    character
    cidr
    circle
    date
    double	float8
    inet
    integer	int int4
    interval
    json
    jsonb
    line
    lseg
    macaddr
    macaddr8
    money
    numeric	decimal
    path
    pg_lsn
    pg_snapshot
    point
    polygon
    real	float4
    smallint	int2
    text
    time
    time
    timestamp
    timestamptz
    tsquery
    tsvector
    txid_snapshot
    uuid
    xml
    tsvector
    tsquery
    jsonpath
    int4range
    int4multirange
    int8range
    int8multirange
    numrange
    nummultirange
    tsrange
    tsmultirange
    tstzrange
    tstzmultirange
    daterange
    datemultirange
>;

#| Postgres-specific checks, code generation, and migration application.
class DB::Migration::Declare::Database::Postgres does DB::Migration::Declare::Database {
    method name(--> Str) { 'postgres' }

    method translate-type(DB::Migration::Declare::ColumnType $type --> Str) {
        given $type {
            when DB::Migration::Declare::ColumnType::Named {
                if .checked {
                    .name ~~ /^(\w+)/;
                    TYPES{$0.lc}:exists ?? .name !! Str
                }
                else {
                    .name
                }
            }
            when DB::Migration::Declare::ColumnType::Array {
                with self.translate-type(.element-type) -> $element-type {
                    $element-type ~ .dimensions.map({ .isa(Whatever) ?? '[]' !! "[$_]"  })
                }
                else {
                    Str
                }
            }
            when DB::Migration::Declare::ColumnType::Boolean {
                'boolean'
            }
            when DB::Migration::Declare::ColumnType::Char {
                'character' ~ (.varying ?? ' varying' !! '') ~ '(' ~ .length ~ ')'
            }
            when DB::Migration::Declare::ColumnType::Date {
                'date'
            }
            when DB::Migration::Declare::ColumnType::Integer {
                given .bytes {
                    when 2 { 'smallint' }
                    when 4 { 'integer' }
                    when 8 { 'bigint' }
                    default { Str }
                }
            }
            when DB::Migration::Declare::ColumnType::Text {
                'text'
            }
            when DB::Migration::Declare::ColumnType::Timestamp {
                'timestamp with time zone'
            }
            default {
                Str
            }
        }
    }

    method increments-type(DB::Migration::Declare::ColumnType $type --> Str) {
        given $type {
            when DB::Migration::Declare::ColumnType::Integer {
                given .bytes {
                    when 2 { 'smallserial' }
                    when 4 { 'serial' }
                    when 8 { 'bigserial' }
                    default { Str }
                }
            }
            when DB::Migration::Declare::ColumnType::Named {
                given .name {
                    when 'smallint' | 'int2' { 'smallserial' }
                    when 'integer' | 'int' | 'int4' { 'serial' }
                    when 'bigint' | 'int8' { 'bigserial' }
                }
            }
            default {
                Str
            }
        }
    }

    method type-supports-increments(DB::Migration::Declare::ColumnType $type --> Bool) {
        so self.increments-type($type)
    }

    method now-expression(DB::Migration::Declare::ColumnType $type --> Str) {
        given $type {
            when DB::Migration::Declare::ColumnType::Date {
                'current_date'
            }
            when DB::Migration::Declare::ColumnType::Timestamp {
                'current_timestamp'
            }
            default {
                fail "Cannot provide a now value for column of type '$type.describe()'";
            }
        }
    }

    proto method translate-up(DB::Migration::Declare::Model::MigrationStep $step --> Str) { * }

    multi method translate-up(DB::Migraion::Declare::Model::CreateTable $create-table --> Str) {
        my @steps = $create-table.steps.map: {
            when DB::Migraion::Declare::Model::AddColumn {
                qq/"{.name}" / ~
                        (.increments ?? self.increments-type(.type) !! self.translate-type(.type)) ~
                        self.default(.default, .type) ~
                        self.nullness(.null)
            }
            when DB::Migraion::Declare::Model::PrimaryKey {
                'PRIMARY KEY (' ~ .column-names.map({ qq{"$_"} }).join(", ") ~ ')'
            }
            when DB::Migraion::Declare::Model::UniqueKey {
                'UNIQUE (' ~ .column-names.map({ qq{"$_"} }).join(", ") ~ ')'
            }
            default {
                die "Sorry, { .^name } is not yet implemented for Postgres up migration generation";
            }
        }
        return qq{CREATE TABLE "$create-table.name()" (\n} ~ @steps.join(",\n") ~ "\n);\n";
    }

    multi method translate-up(DB::Migraion::Declare::Model::DropTable $drop-table --> Str) {
        return qq{DROP TABLE "$drop-table.name()";\n};
    }

    multi method translate-up(DB::Migraion::Declare::Model::ExecuteSQL $execute-sql --> Str) {
        my Str $sql = $execute-sql.up.get-sql(:database(self)).trim-trailing;
        $sql.ends-with(';') ?? "$sql\n" !! "$sql;\n"
    }

    multi method default(DB::Migration::Declare::SQLLiteral:D $sql, DB::Migration::Declare::ColumnType $type --> Str) {
        ' DEFAULT ' ~ $sql.get-sql(:database(self), :expected-type($type))
    }

    multi method default(Numeric:D $value, DB::Migration::Declare::ColumnType --> Str) {
        ' DEFAULT ' ~ $value
    }

    multi method default(Any:U, DB::Migration::Declare::ColumnType --> Str) {
        ''
    }

    method nullness(Bool $null --> Str) {
        $null ?? ' NULL' !! ' NOT NULL'
    }

    method apply-migration-sql(Any $connection, Str $sql --> Nil) {
        $connection.execute($sql);
    }
}
