import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import shard/schema

pub type ParseError {
  UnexpectedEnd
  InvalidSchema(name: String)
}

fn atom_to_type(atom: String) -> String {
  case atom {
    "string" -> "String"
    "integer" | "int" -> "Int"
    "float" -> "Float"
    "boolean" | "bool" -> "Bool"
    _ -> "String"
  }
}

fn parse_field_type(type_str: String) -> #(String, Bool) {
  let trimmed = string.trim(type_str)
  case string.starts_with(trimmed, "[") {
    True -> {
      let raw_inner = trimmed |> string.drop_start(1) |> string.drop_end(1) |> string.trim
      let inner = case string.split(raw_inner, on: ",") {
        [first, ..] -> string.trim(first)
        _ -> raw_inner
      }
      #("List(" <> inner <> ")", False)
    }
    False ->
      case trimmed {
        ":string" | ":integer" | ":int" | ":float" | ":boolean" | ":bool" -> {
          let atom = trimmed |> string.drop_start(1)
          #(atom_to_type(atom), False)
        }
        _ -> #(trimmed, False)
      }
  }
}

fn parse_field_line(line: String) -> Option(#(String, String, Bool)) {
  let trimmed = string.trim(line)
  case string.starts_with(trimmed, "field :") {
    False -> None
    True -> {
      let rest = string.drop_start(trimmed, 7)
      let parts = string.split(rest, on: ", ")
      let #(name_part, type_parts, opt_parts) = case parts {
        [n, ..rest_parts] -> {
          let #(type_parts, opt_parts) =
            list.split_while(rest_parts, fn(p) { !string.contains(string.trim(p), "optional:") })
          #(n, type_parts, opt_parts)
        }
        _ -> #("", [], [])
      }
      case name_part {
        "" -> None
        _ -> {
          let raw = name_part |> string.trim
          let name = case string.starts_with(raw, ":") {
            True -> string.drop_start(raw, 1)
            False -> raw
          }
          let type_str = string.join(type_parts, ", ") |> string.trim
          let optional =
            list.any(opt_parts, fn(p) { string.contains(string.trim(p), "optional:") })
          let #(type_, _) = parse_field_type(type_str)
          let final_type = case optional {
            True -> "Option(" <> type_ <> ")"
            False -> type_
          }
          Some(#(name, final_type, optional))
        }
      }
    }
  }
}

fn parse_defschema_block(block: String) -> Option(schema.Table) {
  let lines = string.split(block, on: "\n")
  let first = list.first(lines)
  let schema_name =
    case first {
      Ok(line) -> {
        let trimmed = string.trim(line)
        case string.starts_with(trimmed, "defschema ") {
          True -> {
            let rest = string.drop_start(trimmed, 10)
            case string.split(rest, on: " ") {
              [name, ..] -> string.trim(name)
              _ -> ""
            }
          }
          False -> ""
        }
      }
      Error(_) -> ""
    }
  case schema_name {
    "" -> None
    name -> {
      let columns =
        lines
        |> list.drop(1)
        |> list.flat_map(fn(line) {
          case parse_field_line(line) {
            Some(t) -> [t]
            None -> []
          }
        })
        |> list.map(fn(t) {
          case t {
            #(col_name, type_, optional) -> schema.Column(name: col_name, type_: type_, optional: optional)
          }
        })
      Some(schema.Table(name: name, columns: columns))
    }
  }
}

fn split_defschema_blocks(source: String) -> List(String) {
  let parts = string.split(source, on: "defschema ")
  parts
  |> list.drop(1)
  |> list.map(fn(p) { "defschema " <> p })
}

pub fn parse(source: String) -> Result(schema.Schema, ParseError) {
  let blocks = split_defschema_blocks(source)
  let tables =
    blocks
    |> list.flat_map(fn(block) {
      case parse_defschema_block(block) {
        Some(t) -> [t]
        None -> []
      }
    })
  Ok(schema.Schema(tables: tables))
}
