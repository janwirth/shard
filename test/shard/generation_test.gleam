import gleam/string
import shard/generator
import shard/parse_helpers

pub fn generate_contains_actions_test() {
  let s = parse_helpers.schema_from_file("test/fixtures/migration_2_students_and_classes.shard.ex")
  let output = generator.generate_schema_module(s)

  assert string.contains(output, "pub fn create(")
  assert string.contains(output, "pub fn update(")
  assert string.contains(output, "pub fn delete(")
  assert string.contains(output, "pub fn list(")
  assert string.contains(output, "StudentRecord")
  assert string.contains(output, "ClassRecord")
  assert string.contains(output, "INSERT INTO Student")
  assert string.contains(output, "INSERT INTO Class")
}
