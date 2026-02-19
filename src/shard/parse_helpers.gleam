import shard/parser
import shard/schema
import simplifile

pub fn schema_from_file(path: String) -> schema.Schema {
  let assert Ok(source) = simplifile.read(from: path)
  let assert Ok(schema) = parser.parse(source)
  schema
}
