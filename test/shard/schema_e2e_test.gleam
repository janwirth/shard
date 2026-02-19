import gleam/list
import gleam/option.{None, Some}
import gleam/string
import shard/parse_helpers
import shard/schema
import schema/class
import schema/student
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

pub fn schema_actions_e2e_test() {
  use conn <- sqlight.with_connection("file:schema_actions_test?mode=memory")

  let s = parse_helpers.schema_from_file("test/fixtures/migration_2_students_and_classes.shard.ex")
  let steps = schema.to_sqlite_migration_steps(s)
  apply_migration_steps(conn, steps)

  let assert Ok(alice_id) =
    student.create(conn, student.StudentRecord(name: "Alice", age: 20, graduation_year: Some(2025)))
  let assert Ok(bob_id) =
    student.create(conn, student.StudentRecord(name: "Bob", age: 21, graduation_year: None))

  let assert Ok(_) = class.create(conn, class.ClassRecord(name: "Math"))
  let assert Ok(_) = class.create(conn, class.ClassRecord(name: "Physics"))

  let assert Ok(students) = student.list(conn)
  assert list.length(students) == 2

  let assert Ok(_) =
    student.update(
      conn,
      alice_id,
      student.StudentRecord(name: "Alice Updated", age: 21, graduation_year: Some(2026)),
    )

  let assert Ok(updated_students) = student.list(conn)
  let alices = list.filter(updated_students, fn(r) { r.name == "Alice Updated" })
  assert list.length(alices) == 1
  assert list.first(alices) == Ok(student.StudentRecord(name: "Alice Updated", age: 21, graduation_year: Some(2026)))

  let assert Ok(_) = student.delete(conn, bob_id)
  let assert Ok(after_delete) = student.list(conn)
  assert list.length(after_delete) == 1

  let assert Ok(classes) = class.list(conn)
  assert classes == [class.ClassRecord(name: "Math"), class.ClassRecord(name: "Physics")]
}
