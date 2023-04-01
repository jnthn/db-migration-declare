#!/usr/bin/env raku
use v6.d;
use DB::Migration::Declare;

migration 'Setup', {
    create-table 'skyscrapers', {
        add-column 'id', integer(), :increments, :primary;
        add-column 'name', text(), :!null, :unique;
        add-column 'height', integer(), :!null;
    }
}

migration 'Add countries', {
    create-table 'countries', {
        add-column 'id', integer(), :increments, :primary;
        add-column 'name', varchar(255), :!null, :unique;
    }
}

migration 'Skypscraper countries', {
    alter-table 'skyscrapers',{
        add-column 'country', integer();
        foreign-key table => 'countries', from => 'country', to => 'id';
    }
}

migration 'Drop countries', {
    alter-table 'skyscrapers', {
        drop-column 'country';
    }
    drop-table 'countries';
}

migration 'Rename column', {
    alter-table 'skyscrapers', {
        rename-column from => 'height', to => 'architectural_height';
        add-column 'equipment_height', integer();
    }
}

migration 'Reanme table', {
    rename-table from => 'skyscrapers', to => 'tall_buildings';
}

migration 'Drop unique key', {
    alter-table 'tall_buildings', {
        drop-unique-key 'name';
    }
}
