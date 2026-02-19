import gleam/dynamic/decode
import gleam/result
import sqlight

pub type ClassRecord {
  ClassRecord(name: String)
}

pub fn create(conn: sqlight.Connection, data: ClassRecord) -> Result(Int, sqlight.Error) {
  case sqlight.query(
    "INSERT INTO Class (name) VALUES (?) RETURNING rowid",
    on: conn,
    with: [
      sqlight.text(data.name)
    ],
    expecting: decode.at([0], decode.int),
  ) {
    Ok([id]) -> Ok(id)
    Ok(_) -> Error(sqlight.SqlightError(sqlight.GenericError, "No row returned", -1))
    Error(e) -> Error(e)
  }
}

pub fn update(conn: sqlight.Connection, id: Int, data: ClassRecord) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "UPDATE Class SET name = ? WHERE rowid = ?",
    on: conn,
    with: [
      sqlight.text(data.name),
      sqlight.int(id),
    ],
    expecting: decode.success(Nil),
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete(conn: sqlight.Connection, id: Int) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "DELETE FROM Class WHERE rowid = ?",
    on: conn,
    with: [sqlight.int(id)],
    expecting: decode.success(Nil),
  )
  |> result.map(fn(_) { Nil })
}

pub fn list(conn: sqlight.Connection) -> Result(List(ClassRecord), sqlight.Error) {
  sqlight.query(
    "SELECT name FROM Class",
    on: conn,
    with: [],
    expecting: decode.field(0, decode.string, fn(name) { decode.success(ClassRecord(name: name)) }),
  )
}
