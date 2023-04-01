use v6.d;
use DB::Migration::Declare::Model;
use DB::Migration::Declare::SQLLiteral;

sub migration(Str $description, &spec --> Nil) is export {
    with $*DMD-MIGRATION-LIST -> $list {
        my $file = &spec.?file // 'Unknwon';
        my $line = &spec.?line // 0;
        my $*DMD-MODEL = DB::Migraion::Declare::Model::Migration.new(:$description, :$file, :$line);
        spec();
        $list.add-migration($*DMD-MODEL);
    }
    else {
        die "Can only use `migration` when a migration list is set up to collect them";
    }
}

sub create-table(Str $name, &spec --> Nil) is export {
    ensure-in-migrate('create-table');
    my $*DMD-MODEL-TABLE = DB::Migraion::Declare::Model::CreateTable.new(:$name);
    $*DMD-MODEL.add-step($*DMD-MODEL-TABLE);
    my Str @*PRIMARIES;
    my Str @*UNIQUES;
    spec();
    primary-key |@*PRIMARIES if @*PRIMARIES;
    unique-key $_ for @*UNIQUES;
}

sub alter-table(Str $name, &spec --> Nil) is export {
    ensure-in-migrate('alter-table');
    my $*DMD-MODEL-TABLE = DB::Migraion::Declare::Model::AlterTable.new(:$name);
    $*DMD-MODEL.add-step($*DMD-MODEL-TABLE);
    my Str @*UNIQUES;
    spec();
    unique-key $_ for @*UNIQUES;
}

multi sub rename-table(Str $from, Str $to --> Nil) is export {
    ensure-in-migrate('rename-table');
    $*DMD-MODEL.add-step(DB::Migraion::Declare::Model::RenameTable.new(:$from, :$to));
}

multi sub rename-table(Str :$from!, Str :$to! --> Nil) is export {
    rename-table($from, $to);
}

multi sub rename-table(Pair $renaming --> Nil) is export {
    rename-table(~$renaming.key, ~$renaming.value);
}

sub drop-table(Str $name --> Nil) is export {
    ensure-in-migrate('drop-table');
    $*DMD-MODEL.add-step(DB::Migraion::Declare::Model::DropTable.new(:$name));
}

sub add-column(Str $name, $type, Bool :$increments, Bool :$null = !$increments, Any :$default,
        Bool :$primary, Bool :$unique --> Nil) is export {
    ensure-in-table('add-column');
    $*DMD-MODEL-TABLE.add-step: DB::Migraion::Declare::Model::AddColumn.new:
            :$name, :type(parse-type($type, "of column '$name'")), :$null, :$default, :$increments;
    @*UNIQUES.push($name) if $unique;
    if $primary {
        if $*DMD-MODEL-TABLE ~~ DB::Migraion::Declare::Model::CreateTable {
            @*PRIMARIES.push($name);
        }
        else {
            die "Can only use the :primary option on a column within the scope of create-table;\n" ~
                    "use a separate primary-key call if you really wish to change the primary key of the table";
        }
    }
}

multi rename-column(Str $from, Str $to --> Nil) is export {
    ensure-in-alter-table('rename-column');
    $*DMD-MODEL-TABLE.add-step(DB::Migraion::Declare::Model::RenameColumn.new(:$from, :$to));
}

multi rename-column(Str :$from!, Str :$to! --> Nil) is export {
    rename-column($from, $to);
}

multi rename-column(Pair $renaming --> Nil) is export {
    rename-column(~$renaming.key, ~$renaming.value);
}

sub drop-column(Str $name --> Nil) is export {
    ensure-in-alter-table('drop-column');
    $*DMD-MODEL-TABLE.add-step(DB::Migraion::Declare::Model::DropColumn.new(:$name));
}

sub primary-key(*@column-names --> Nil) is export {
    ensure-in-table('primary-key');
    $*DMD-MODEL-TABLE.add-step(DB::Migraion::Declare::Model::PrimaryKey.new(:@column-names));
}

sub unique-key(*@column-names --> Nil) is export {
    ensure-in-table('unique-key');
    $*DMD-MODEL-TABLE.add-step(DB::Migraion::Declare::Model::UniqueKey.new(:@column-names));
}

sub drop-unique-key(*@column-names --> Nil) is export {
    ensure-in-table('drop-unique-key');
    $*DMD-MODEL-TABLE.add-step(DB::Migraion::Declare::Model::DropUniqueKey.new(:@column-names));
}

multi sub foreign-key(Str :$from!, Str :$table!, Str :$to = $from, Bool :$restrict = False,
                      Bool :$cascade = False --> Nil) is export {
    foreign-key :from[$from], :$table, :to[$to], :$restrict, :$cascade
}
multi sub foreign-key(:@from!, Str :$table!, :@to = @from, Bool :$restrict = False,
                      Bool :$cascade = False --> Nil) is export {
    $*DMD-MODEL-TABLE.add-step: DB::Migraion::Declare::Model::ForeignKey.new:
            :@from, :$table, :@to, :$restrict, :$cascade
}
sub foriegn-key(|c) is export is DEPRECATED {
    foreign-key(|c)
}

multi sub execute(DB::Migration::Declare::SQLLiteral :$up!, DB::Migration::Declare::SQLLiteral :$down! --> Nil) is export {
    ensure-in-migrate('execute');
    $*DMD-MODEL.add-step(DB::Migraion::Declare::Model::ExecuteSQL.new(:$up, :$down));
}


sub char(Int $length --> DB::Migration::Declare::ColumnType::Char) is export {
    DB::Migration::Declare::ColumnType::Char.new(:$length, :!varying)
}

sub varchar(Int $length --> DB::Migration::Declare::ColumnType::Char) is export {
    DB::Migration::Declare::ColumnType::Char.new(:$length, :varying)
}

sub text(--> DB::Migration::Declare::ColumnType::Text) is export {
    DB::Migration::Declare::ColumnType::Text.new
}

sub boolean(--> DB::Migration::Declare::ColumnType::Boolean) is export {
    DB::Migration::Declare::ColumnType::Boolean.new
}

sub integer(Int $bytes = 4 --> DB::Migration::Declare::ColumnType::Integer) is export {
    DB::Migration::Declare::ColumnType::Integer.new(:$bytes)
}

sub date(--> DB::Migration::Declare::ColumnType::Date) is export {
    DB::Migration::Declare::ColumnType::Date.new
}

sub timestamp(Bool :$timezone = False --> DB::Migration::Declare::ColumnType::Timestamp) is export {
    DB::Migration::Declare::ColumnType::Timestamp.new(:$timezone)
}

sub arr($type, *@dimensions --> DB::Migration::Declare::ColumnType::Array) is export {
    @dimensions ||= *;
    my $element-type = parse-type($type, 'of array type');
    for @dimensions {
        when Whatever {}
        when Int {}
        default {
            die "Unrecognized array dimension specifier; must be Int or *";
        }
    }
    DB::Migration::Declare::ColumnType::Array.new(:$element-type, :@dimensions)
}

sub type(Str $name, Bool :$checked = True --> DB::Migration::Declare::ColumnType::Named) is export {
    DB::Migration::Declare::ColumnType::Named.new(:$name, :$checked)
}


multi sub sql(Str $sql --> DB::Migration::Declare::SQLLiteral::Agnostic) is export {
    DB::Migration::Declare::SQLLiteral::Agnostic.new(:$sql)
}

multi sub sql(*%options --> DB::Migration::Declare::SQLLiteral::Specific) is export {
    DB::Migration::Declare::SQLLiteral::Specific.new(:%options)
}

sub now(--> DB::Migration::Declare::SQLLiteral::Now) is export {
    DB::Migration::Declare::SQLLiteral::Now.new
}


multi parse-type(DB::Migration::Declare::ColumnType $type, Str --> DB::Migration::Declare::ColumnType) {
    # Already a column type specification object, so just return it.
    $type
}

multi parse-type(Any $type, Str $hint) {
    die "Cannot parse type '$type.raku()' $hint"
}

sub ensure-in-migrate(Str $what --> Nil) {
    without $*DMD-MODEL {
        die "Can only use $what within the scope of a migration";
    }
}

sub ensure-in-table(Str $what --> Nil) {
    without $*DMD-MODEL-TABLE {
        die "Can only use $what within the scope of create-table or alter-table";
    }
}

sub ensure-in-alter-table(Str $what --> Nil) {
    unless $*DMD-MODEL-TABLE ~~ DB::Migraion::Declare::Model::AlterTable {
        die "Can only use $what within the scope of alter-table";
    }
}
