import gleam/bool
import gleam/list
import gleam/string
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

type TodoItem {
  TodoItem(id: Int, text: String, completed: Bool)
}

type Filter {
  All
  Active
  Completed
}

type Model {
  Model(
    todos: List(TodoItem),
    input: String,
    next_id: Int,
    filter: Filter,
  )
}

type Msg {
  UpdateInput(String)
  AddTodo
  ToggleTodo(Int)
  DeleteTodo(Int)
  SetFilter(Filter)
}

fn init(_) -> Model {
  Model(
    todos: [],
    input: "",
    next_id: 0,
    filter: All,
  )
}

fn update(model: Model, msg: Msg) -> Model {
  case msg {
    UpdateInput(text) -> {
      case model {
        Model(todos, _, next_id, filter) ->
          Model(todos: todos, input: text, next_id: next_id, filter: filter)
      }
    }
    AddTodo -> {
      case model {
        Model(todos, input, next_id, filter) -> {
          let text = string.trim(input)
          case string.is_empty(text) {
            True -> model
            False -> Model(
              todos: list.append(todos, [TodoItem(id: next_id, text: text, completed: False)]),
              input: "",
              next_id: next_id + 1,
              filter: filter,
            )
          }
        }
      }
    }
    ToggleTodo(id) -> {
      case model {
        Model(todos, input, next_id, filter) ->
          Model(
            todos: list.map(todos, fn(t) {
              case t {
                TodoItem(i, text, completed) if i == id -> TodoItem(i, text, bool.negate(completed))
                other -> other
              }
            }),
            input: input,
            next_id: next_id,
            filter: filter,
          )
      }
    }
    DeleteTodo(id) -> {
      case model {
        Model(todos, input, next_id, filter) ->
          Model(
            todos: list.filter(todos, fn(t) {
              case t {
                TodoItem(i, _, _) -> i != id
              }
            }),
            input: input,
            next_id: next_id,
            filter: filter,
          )
      }
    }
    SetFilter(f) -> {
      case model {
        Model(todos, input, next_id, _) ->
          Model(todos: todos, input: input, next_id: next_id, filter: f)
      }
    }
  }
}

fn view(model: Model) -> Element(Msg) {
  case model {
    Model(todos, input, _, filter) -> {
      let filtered = filter_todos(todos, filter)
      html.div([], [
        html.h1([], [html.text("Todos")]),
        html.form(
          [event.on_submit(fn(_) { AddTodo })],
          [
            html.input([
              attribute.value(input),
              attribute.placeholder("What needs to be done?"),
              event.on_input(UpdateInput),
            ]),
            html.button([], [html.text("Add")]),
          ],
        ),
        html.ul([], list.map(filtered, todo_item)),
        filter_buttons(filter),
      ])
    }
  }
}

fn filter_todos(todos: List(TodoItem), filter: Filter) -> List(TodoItem) {
  case filter {
    All -> todos
    Active -> list.filter(todos, fn(t) {
      case t {
        TodoItem(_, _, completed) -> bool.negate(completed)
      }
    })
    Completed -> list.filter(todos, fn(t) {
      case t {
        TodoItem(_, _, completed) -> completed
      }
    })
  }
}

fn todo_item(item: TodoItem) -> Element(Msg) {
  case item {
    TodoItem(id, text, completed) -> {
      html.li([], [
        html.input([
          attribute.type_("checkbox"),
          attribute.checked(completed),
          event.on_click(ToggleTodo(id)),
        ]),
        html.span(
          case completed {
            True -> [attribute.styles([#("text-decoration", "line-through"), #("opacity", "0.6")])]
            False -> []
          },
          [html.text(text)],
        ),
        html.button(
          [event.on_click(DeleteTodo(id))],
          [html.text("×")],
        ),
      ])
    }
  }
}

fn filter_buttons(current: Filter) -> Element(Msg) {
  html.div([], [
    filter_btn(All, "All", current),
    filter_btn(Active, "Active", current),
    filter_btn(Completed, "Completed", current),
  ])
}

fn filter_btn(filter: Filter, label: String, current: Filter) -> Element(Msg) {
  let selected = filter == current
  let style_attrs = case selected {
    True -> [attribute.styles([#("opacity", "1"), #("font-weight", "bold")])]
    False -> [attribute.styles([#("opacity", "0.6")])]
  }
  html.button(
    list.append([event.on_click(SetFilter(filter))], style_attrs),
    [html.text(label)],
  )
}
