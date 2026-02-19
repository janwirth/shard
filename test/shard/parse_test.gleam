import shard/parse_helpers
import shard/schema

pub fn parse_example_shard_test() {
  let parsed = parse_helpers.schema_from_file("test/fixtures/example_schema.shard.ex")

  let expected = schema.Schema(tables: [
    schema.Table(
      name: "Student",
      columns: [
        schema.Column(name: "name", type_: "String", optional: False),
        schema.Column(name: "age", type_: "Int", optional: False),
        schema.Column(name: "graduation_year", type_: "Option(Int)", optional: True),
        schema.Column(name: "classes", type_: "List(Class)", optional: False),
      ],
    ),
    schema.Table(
      name: "Class",
      columns: [
        schema.Column(name: "name", type_: "String", optional: False),
        schema.Column(name: "students", type_: "List(Student)", optional: False),
      ],
    ),
  ])

  assert parsed == expected
}

pub fn sqlite_migration_steps_test() {
  let s = schema.Schema(tables: [
    schema.Table(
      name: "Student",
      columns: [
        schema.Column(name: "name", type_: "String", optional: False),
        schema.Column(name: "graduation_year", type_: "Option(Int)", optional: True),
      ],
    ),
  ])

  let steps = schema.to_sqlite_migration_steps(s)

  assert steps == [
    "CREATE TABLE IF NOT EXISTS Student (name TEXT NOT NULL, graduation_year INTEGER);",
    "ALTER TABLE Student ADD COLUMN name TEXT NOT NULL;",
    "ALTER TABLE Student ADD COLUMN graduation_year INTEGER;",
  ]
}
