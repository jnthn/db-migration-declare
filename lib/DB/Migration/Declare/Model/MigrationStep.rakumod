use v6.d;

#| Role done by all migration steps.
role DB::Migration::Declare::Model::MigrationStep {
    #| Returns a SHA-1 hash of this migration step.
    method hashed(--> Str) { ... }
}
