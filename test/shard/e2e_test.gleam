import gleam/dynamic/decode
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import shard/parse_helpers
import shard/schema
import sqlight

fn apply_migration_steps(conn: sqlight.Connection, steps: List(String)) -> Nil {
  list.each(steps, fn(step) {
    case sqlight.exec(step, on: conn) {
      Ok(_) -> Nil
      Error(sqlight.SqlightError(_, message, _)) ->
        case string.contains(message, "duplicate column") {
          True -> Nil
          False -> panic as message
        }
    }
  })
}

pub fn fresh_database_test() {
  use conn <- sqlight.with_connection("file:fresh_test?mode=memory")

  let s = parse_helpers.schema_from_file("test/fixtures/migration_1_students.shard.ex")
  let steps = schema.to_sqlite_migration_steps(s)
  apply_migration_steps(conn, steps)

  let assert Ok(_) =
    sqlight.exec(
      "INSERT INTO Student (name, age, graduation_year) VALUES ('Alice', 20, 2025);",
      on: conn,
    )
  let assert Ok(_) =
    sqlight.exec(
      "INSERT INTO Student (name, age, graduation_year) VALUES ('Bob', 21, NULL);",
      on: conn,
    )

  let decoder =
    decode.field(0, decode.string, fn(name) {
      decode.field(1, decode.int, fn(age) {
        decode.field(2, decode.optional(decode.int), fn(gy) {
          decode.success(#(name, age, gy))
        })
      })
    })
  let assert Ok(rows) =
    sqlight.query("SELECT name, age, graduation_year FROM Student ORDER BY name", on: conn, with: [], expecting: decoder)

  assert rows == [#("Alice", 20, Some(2025)), #("Bob", 21, None)]
}

pub fn schema_evolution_test() {
  use conn <- sqlight.with_connection("file:evolution_test?mode=memory")

  let steps1 = schema.to_sqlite_migration_steps(parse_helpers.schema_from_file("test/fixtures/migration_1_students.shard.ex"))
  apply_migration_steps(conn, steps1)

  let assert Ok(_) =
    sqlight.exec(
      "INSERT INTO Student (name, age, graduation_year) VALUES ('Alice', 20, 2025);",
      on: conn,
    )

  let steps2 =
    schema.to_sqlite_migration_steps(parse_helpers.schema_from_file("test/fixtures/migration_2_students_and_classes.shard.ex"))
  apply_migration_steps(conn, steps2)

  let assert Ok(_) =
    sqlight.exec(
      "INSERT INTO Student (name, age, graduation_year) VALUES ('Bob', 21, NULL);",
      on: conn,
    )
  let assert Ok(_) =
    sqlight.exec(
      "INSERT INTO Class (name) VALUES ('Math');",
      on: conn,
    )
  let assert Ok(_) =
    sqlight.exec(
      "INSERT INTO Class (name) VALUES ('Physics');",
      on: conn,
    )

  let student_decoder =
    decode.field(0, decode.string, fn(name) {
      decode.field(1, decode.int, fn(age) {
        decode.field(2, decode.optional(decode.int), fn(gy) {
          decode.success(#(name, age, gy))
        })
      })
    })
  let assert Ok(students) =
    sqlight.query("SELECT name, age, graduation_year FROM Student ORDER BY name", on: conn, with: [], expecting: student_decoder)
  assert students == [#("Alice", 20, Some(2025)), #("Bob", 21, None)]

  let class_decoder = decode.at([0], decode.string)
  let assert Ok(classes) =
    sqlight.query("SELECT name FROM Class ORDER BY name", on: conn, with: [], expecting: class_decoder)
  assert classes == ["Math", "Physics"]
}
