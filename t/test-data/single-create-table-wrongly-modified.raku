#!/usr/bin/env raku
use v6.d;
use DB::Migration::Declare;

migration 'Setup', {
    create-table 'skyscrapers', {
        add-column 'id', integer(), :increments, :primary;
        add-column 'name', text(), :!null, :unique;
        add-column 'height', integer(), :!null;
        add-column 'held_record', boolean(), :!null
    }
}
