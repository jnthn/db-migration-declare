use v6.d;
use DB::Migration::Declare::Database;
use DB::Migration::Declare::MigrationDirection;
use DB::Migration::Declare::MigrationHistory;
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
                self!column($_)
            }
            when DB::Migraion::Declare::Model::PrimaryKey {
                self!primary-key($_)
            }
            when DB::Migraion::Declare::Model::UniqueKey {
                self!unique-key($_)
            }
            when DB::Migraion::Declare::Model::ForeignKey {
                self!foreign-key($_)
            }
            default {
                die "Sorry, { .^name } is not yet implemented for Postgres up migration generation";
            }
        }
        return qq{CREATE TABLE "$create-table.name()" (\n} ~ @steps.join(",\n") ~ "\n);\n";
    }

    multi method translate-up(DB::Migraion::Declare::Model::AlterTable $alter-table --> Str) {
        my @steps = $alter-table.steps.map: {
            when DB::Migraion::Declare::Model::AddColumn {
                'ADD COLUMN ' ~ self!column($_)
            }
            when DB::Migraion::Declare::Model::DropColumn {
                'DROP COLUMN "' ~ .name ~ '"'
            }
            when DB::Migraion::Declare::Model::PrimaryKey {
                'ADD ' ~ self!primary-key($_)
            }
            when DB::Migraion::Declare::Model::UniqueKey {
                'ADD ' ~ self!unique-key($_)
            }
            when DB::Migraion::Declare::Model::ForeignKey {
                'ADD ' ~ self!foreign-key($_)
            }
            default {
                die "Sorry, { .^name } is not yet implemented for Postgres up migration generation";
            }
        }
        return qq{ALTER TABLE "$alter-table.name()"\n} ~ @steps.join(",\n") ~ ";\n";
    }

    multi method translate-up(DB::Migraion::Declare::Model::DropTable $drop-table --> Str) {
        return qq{DROP TABLE "$drop-table.name()";\n};
    }

    multi method translate-up(DB::Migraion::Declare::Model::ExecuteSQL $execute-sql --> Str) {
        my Str $sql = $execute-sql.up.get-sql(:database(self)).trim-trailing;
        $sql.ends-with(';') ?? "$sql\n" !! "$sql;\n"
    }

    method !column(DB::Migraion::Declare::Model::AddColumn $_ --> Str) {
        qq/"{.name}" / ~
                (.increments ?? self.increments-type(.type) !! self.translate-type(.type)) ~
                self.default(.default, .type) ~
                self.nullness(.null)
    }

    method !primary-key(DB::Migraion::Declare::Model::PrimaryKey $_ --> Str) {
        'PRIMARY KEY (' ~ .column-names.map({ qq{"$_"} }).join(", ") ~ ')'
    }

    method !unique-key(DB::Migraion::Declare::Model::UniqueKey $_ --> Str) {
        'UNIQUE (' ~ .column-names.map({ qq{"$_"} }).join(", ") ~ ')'
    }

    method !foreign-key(DB::Migraion::Declare::Model::ForeignKey $_ --> Str) {
        'FOREIGN KEY (' ~ .from.map({ qq{"$_"} }).join(", ") ~ ') REFERENCES "' ~ .table ~
                '" (' ~ .to.map({ qq{"$_"} }).join(", ") ~ ')' ~
                (.cascade ?? ' ON DELETE CASCADE' !! .restrict ?? ' ON DELETE RESTRICT' !! '')
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

    method ensure-migration-state-storage(Any $connection --> Nil) {
        # Postgres 9.1+ support the IF NOT EXISTS syntax; that was released in 2011, and such
        # versions are already EOL two times over, so depend on it.
        $connection.execute: q:to/SETUP/
            CREATE TABLE IF NOT EXISTS raku_dmd_migration_state (
                id serial NOT NULL,
                -- The schema ID, used to distinguish different sets of migrations.
                schema varchar(255) NOT NULL,
                -- A version number of the database after this application, used for an
                -- ordering of changes.
                version integer NOT NULL,
                -- The hash of the migration applied.
                migration varchar(40) NOT NULL,
                -- Was it a migration up or down?
                up boolean NOT NULL,
                -- The migration's description; informational/degugging use only.
                description text NOT NULL,
                -- When the migration was applied.
                applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE (schema, version)
            );
            SETUP
    }

    method load-migration-history(Any $connection, Str $schema-id --> DB::Migration::Declare::MigrationHistory) {
        my @raw-entries = $connection.query(q:to/SQL/, $schema-id).hashes;
            SELECT version, migration, up, description, applied_at
            FROM raku_dmd_migration_state
            WHERE schema = $1
            SQL
        DB::Migration::Declare::MigrationHistory.new: entries => @raw-entries.map: -> %entry {
            DB::Migration::Declare::MigrationHistory::Entry.new:
                    version => %entry<version>,
                    hash => %entry<migration>,
                    direction => %entry<up> ?? MigrationDirection::Up !! MigrationDirection::Down,
                    description => %entry<description>,
                    applied-at => %entry<applied_at>
        }
    }

    method add-migration-history-entry(Any $connection, Str $schema-id, Int $version, Str $hash,
                                       MigrationDirection $direction, Str $description --> Nil) {
        $connection.query: q:to/SQL/, $schema-id, $version, $hash, $direction == MigrationDirection::Up, $description;
            INSERT INTO raku_dmd_migration_state (schema, version, migration, up, description)
            VALUES ($1, $2, $3, $4, $5);
            SQL
    }

    method apply-migration-sql(Any $connection, Str $sql --> Nil) {
        $connection.execute($sql);
    }
}
