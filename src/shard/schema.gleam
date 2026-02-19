import gleam/list
import gleam/string

pub type Column {
  Column(name: String, type_: String, optional: Bool)
}

pub type Table {
  Table(name: String, columns: List(Column))
}

pub type Schema {
  Schema(tables: List(Table))
}

fn gleam_type_to_sqlite(type_: String, _optional: Bool) -> String {
  case type_ {
    "String" -> "TEXT"
    "Int" | "Int32" | "Int64" -> "INTEGER"
    "Float" | "Float32" | "Float64" -> "REAL"
    "Bool" -> "INTEGER"
    t ->
      case string.starts_with(t, "Option(") {
        True -> gleam_type_to_sqlite(inner_type(t), True)
        False -> "TEXT"
      }
  }
}

fn inner_type(option_type: String) -> String {
  option_type
  |> string.drop_start(7)
  |> string.drop_end(1)
}

fn parse_column_type(type_: String) -> #(String, Bool) {
  case string.starts_with(type_, "Option(") {
    True -> #(inner_type(type_), True)
    False -> #(type_, False)
  }
}

pub fn to_sqlite_migration_steps(schema: Schema) -> List(String) {
  list.flat_map(schema.tables, fn(table) {
    case table {
      Table(name, columns) -> {
        let col_defs =
          list.map(columns, fn(col) {
            case col {
              Column(col_name, type_, optional) -> {
                let #(inner_type, _) = parse_column_type(type_)
                let sql_type = gleam_type_to_sqlite(inner_type, optional)
                let constraint = case optional { True -> "" False -> " NOT NULL" }
                col_name <> " " <> sql_type <> constraint
              }
            }
          })
        let create_sql =
          "CREATE TABLE IF NOT EXISTS " <> name <> " (" <> string.join(col_defs, ", ") <> ");"
        let alter_steps =
          list.map(columns, fn(col) {
            case col {
              Column(col_name, type_, optional) -> {
                let #(inner_type, _) = parse_column_type(type_)
                let sql_type = gleam_type_to_sqlite(inner_type, optional)
                let constraint = case optional { True -> "" False -> " NOT NULL" }
                "ALTER TABLE " <> name <> " ADD COLUMN " <> col_name <> " " <> sql_type <> constraint <> ";"
              }
            }
          })
        [create_sql, ..alter_steps]
      }
    }
  })
}
