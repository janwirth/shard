import argv
import gleam/io
import shard/generator
import shard/parse_helpers
import simplifile

pub fn main() -> Nil {
  case argv.load().arguments {
    ["generate", schema_path, output_dir] -> {
      let s = parse_helpers.schema_from_file(schema_path)
      case generator.generate_schema_files(s, output_dir) {
        Ok(_) -> io.println("Generated Schema files to " <> output_dir <> "/schema/")
        Error(e) -> io.println("Error: " <> simplifile.describe_error(e))
      }
    }
    _ -> io.println("Usage: gleam run -- generate <schema_path> <output_dir>")
  }
}
