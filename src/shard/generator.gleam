import gleam/int
import gleam/list
import gleam/result
import gleam/string
import shard/schema
import simplifile

fn is_scalar_column(type_: String) -> Bool {
  case string.starts_with(type_, "List(") {
    True -> False
    False -> True
  }
}

fn scalar_columns(table: schema.Table) -> List(schema.Column) {
  case table {
    schema.Table(_, columns) ->
      list.filter(columns, fn(c) {
        case c {
          schema.Column(_, type_, _) -> is_scalar_column(type_)
        }
      })
  }
}

fn gleam_type_for_column(col: schema.Column) -> String {
  case col {
    schema.Column(_, type_, _) -> type_
  }
}

fn column_name(col: schema.Column) -> String {
  case col {
    schema.Column(name, _, _) -> name
  }
}

fn sqlight_value_expr(type_: String, field: String) -> String {
  case type_ {
    "String" -> "sqlight.text(" <> field <> ")"
    "Int" | "Int32" | "Int64" -> "sqlight.int(" <> field <> ")"
    "Float" | "Float32" | "Float64" -> "sqlight.float(" <> field <> ")"
    "Bool" -> "sqlight.bool(" <> field <> ")"
    t ->
      case string.starts_with(t, "Option(") {
        True -> "sqlight.nullable(sqlight.int, " <> field <> ")"
        False -> "sqlight.text(" <> field <> ")"
      }
  }
}

fn inner_type(option_type: String) -> String {
  option_type
  |> string.drop_start(7)
  |> string.drop_end(1)
}

fn decode_for_type(type_: String) -> String {
  case type_ {
    "String" -> "decode.string"
    "Int" | "Int32" | "Int64" -> "decode.int"
    "Float" | "Float32" | "Float64" -> "decode.float"
    "Bool" -> "sqlight.decode_bool"
    t ->
      case string.starts_with(t, "Option(") {
        True -> "decode.optional(" <> decode_for_type(inner_type(t)) <> ")"
        False -> "decode.string"
      }
  }
}

fn record_type_name(table_name: String) -> String {
  table_name <> "Record"
}

fn generate_record_type(table: schema.Table) -> String {
  case table {
    schema.Table(name, _) -> {
      let cols = scalar_columns(table)
      let fields =
        list.map(cols, fn(c) {
          let col_name = column_name(c)
          let gleam_type = gleam_type_for_column(c)
          col_name <> ": " <> gleam_type
        })
        |> string.join(", ")
      "pub type " <> record_type_name(name) <> " {\n  " <> record_type_name(name) <> "(" <> fields <> ")\n}"
    }
  }
}

fn generate_create(table: schema.Table) -> String {
  case table {
    schema.Table(name, _) -> {
      let cols = scalar_columns(table)
      let col_names = list.map(cols, column_name) |> string.join(", ")
      let placeholders = list.repeat("?", list.length(cols)) |> string.join(", ")
      let params =
        list.map(cols, fn(c) {
          let cn = column_name(c)
          let gt = gleam_type_for_column(c)
          "      " <> sqlight_value_expr(gt, "data." <> cn)
        })
        |> string.join(",\n")
      "pub fn create(conn: sqlight.Connection, data: " <> record_type_name(name) <> ") -> Result(Int, sqlight.Error) {\n  case sqlight.query(\n    \"INSERT INTO " <> name <> " (" <> col_names <> ") VALUES (" <> placeholders <> ") RETURNING rowid\",\n    on: conn,\n    with: [\n" <> params <> "\n    ],\n    expecting: decode.at([0], decode.int),\n  ) {\n    Ok([id]) -> Ok(id)\n    Ok(_) -> Error(sqlight.SqlightError(sqlight.GenericError, \"No row returned\", -1))\n    Error(e) -> Error(e)\n  }\n}"
    }
  }
}

fn generate_update(table: schema.Table) -> String {
  case table {
    schema.Table(name, _) -> {
      let cols = scalar_columns(table)
      let set_clause =
        list.map(cols, fn(c) { column_name(c) <> " = ?" })
        |> string.join(", ")
      let params =
        list.map(cols, fn(c) {
          let cn = column_name(c)
          let gt = gleam_type_for_column(c)
          "      " <> sqlight_value_expr(gt, "data." <> cn)
        })
        |> string.join(",\n")
      "pub fn update(conn: sqlight.Connection, id: Int, data: " <> record_type_name(name) <> ") -> Result(Nil, sqlight.Error) {\n  sqlight.query(\n    \"UPDATE " <> name <> " SET " <> set_clause <> " WHERE rowid = ?\",\n    on: conn,\n    with: [\n" <> params <> ",\n      sqlight.int(id),\n    ],\n    expecting: decode.success(Nil),\n  )\n  |> result.map(fn(_) { Nil })\n}"
    }
  }
}

fn generate_delete(table: schema.Table) -> String {
  case table {
    schema.Table(name, _) ->
      "pub fn delete(conn: sqlight.Connection, id: Int) -> Result(Nil, sqlight.Error) {\n  sqlight.query(\n    \"DELETE FROM " <> name <> " WHERE rowid = ?\",\n    on: conn,\n    with: [sqlight.int(id)],\n    expecting: decode.success(Nil),\n  )\n  |> result.map(fn(_) { Nil })\n}"
  }
}

fn build_nested_decoder(
  cols: List(schema.Column),
  all_cols: List(schema.Column),
  table_name: String,
  index: Int,
) -> String {
  case cols {
    [] -> "decode.success(" <> build_record_constructor(all_cols, table_name) <> ")"
    [c, ..rest] -> {
      let cn = column_name(c)
      let dt = decode_for_type(gleam_type_for_column(c))
      let inner = build_nested_decoder(rest, all_cols, table_name, index + 1)
      "decode.field(" <> int.to_string(index) <> ", " <> dt <> ", fn(" <> cn <> ") { " <> inner <> " })"
    }
  }
}

fn build_record_constructor(cols: List(schema.Column), table_name: String) -> String {
  case cols {
    [] -> record_type_name(table_name) <> "()"
    _ -> {
      let args =
        list.map(cols, fn(c) {
          let cn = column_name(c)
          cn <> ": " <> cn
        })
        |> string.join(", ")
      record_type_name(table_name) <> "(" <> args <> ")"
    }
  }
}

fn generate_list(table: schema.Table) -> String {
  case table {
    schema.Table(name, _) -> {
      let cols = scalar_columns(table)
      let col_names = list.map(cols, column_name) |> string.join(", ")
      let decoder = build_nested_decoder(cols, cols, name, 0)
      "pub fn list(conn: sqlight.Connection) -> Result(List(" <> record_type_name(name) <> "), sqlight.Error) {\n  sqlight.query(\n    \"SELECT " <> col_names <> " FROM " <> name <> "\",\n    on: conn,\n    with: [],\n    expecting: " <> decoder <> ",\n  )\n}"
    }
  }
}

fn generate_table_module(table: schema.Table) -> String {
  case table {
    schema.Table(_name, _) -> {
      let record = generate_record_type(table)
      let create = generate_create(table)
      let update = generate_update(table)
      let delete = generate_delete(table)
      let list = generate_list(table)
      "import gleam/dynamic/decode\nimport gleam/result\nimport sqlight\n\n" <> record <> "\n\n" <> create <> "\n\n" <> update <> "\n\n" <> delete <> "\n\n" <> list <> "\n"
    }
  }
}

pub fn generate_schema_module(s: schema.Schema) -> String {
  s.tables
  |> list.map(generate_table_module)
  |> string.join("\n")
}

pub fn generate_schema_files(s: schema.Schema, output_dir: String) -> Result(Nil, simplifile.FileError) {
  let schema_dir = output_dir <> "/schema"
  use _ <- result.try(simplifile.create_directory_all(schema_dir))
  list.fold(s.tables, Ok(Nil), fn(acc, table) {
    use _ <- result.try(acc)
    case table {
      schema.Table(name, _) -> {
        let content = generate_table_module(table)
        let file_name = string.lowercase(name)
        let path = schema_dir <> "/" <> file_name <> ".gleam"
        simplifile.write(to: path, contents: content)
      }
    }
  })
}
