import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/result
import sqlight

pub type StudentRecord {
  StudentRecord(name: String, age: Int, graduation_year: Option(Int))
}

pub fn create(conn: sqlight.Connection, data: StudentRecord) -> Result(Int, sqlight.Error) {
  case sqlight.query(
    "INSERT INTO Student (name, age, graduation_year) VALUES (?, ?, ?) RETURNING rowid",
    on: conn,
    with: [
      sqlight.text(data.name),
      sqlight.int(data.age),
      sqlight.nullable(sqlight.int, data.graduation_year)
    ],
    expecting: decode.at([0], decode.int),
  ) {
    Ok([id]) -> Ok(id)
    Ok(_) -> Error(sqlight.SqlightError(sqlight.GenericError, "No row returned", -1))
    Error(e) -> Error(e)
  }
}

pub fn update(conn: sqlight.Connection, id: Int, data: StudentRecord) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "UPDATE Student SET name = ?, age = ?, graduation_year = ? WHERE rowid = ?",
    on: conn,
    with: [
      sqlight.text(data.name),
      sqlight.int(data.age),
      sqlight.nullable(sqlight.int, data.graduation_year),
      sqlight.int(id),
    ],
    expecting: decode.success(Nil),
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete(conn: sqlight.Connection, id: Int) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "DELETE FROM Student WHERE rowid = ?",
    on: conn,
    with: [sqlight.int(id)],
    expecting: decode.success(Nil),
  )
  |> result.map(fn(_) { Nil })
}

pub fn list(conn: sqlight.Connection) -> Result(List(StudentRecord), sqlight.Error) {
  sqlight.query(
    "SELECT name, age, graduation_year FROM Student",
    on: conn,
    with: [],
    expecting: decode.field(0, decode.string, fn(name) { decode.field(1, decode.int, fn(age) { decode.field(2, decode.optional(decode.int), fn(graduation_year) { decode.success(StudentRecord(name: name, age: age, graduation_year: graduation_year)) }) }) }),
  )
}
