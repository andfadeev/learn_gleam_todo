import envoy
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/json
import gleam/option
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp
import mist
import wisp.{type Request, type Response}
import wisp/wisp_mist
import youid/uuid

type TodoItem {
  TodoItem(
    id: uuid.Uuid,
    title: String,
    description: option.Option(String),
    status: String,
    created_at: timestamp.Timestamp,
    updated_at: timestamp.Timestamp,
  )
}

fn timestamp_to_json(ts: timestamp.Timestamp) {
  json.string(timestamp.to_rfc3339(ts, calendar.utc_offset))
}

fn todo_item_to_json(item: TodoItem) {
  json.object([
    #("id", json.string(uuid.to_string(item.id))),
    #("title", json.string(item.title)),
    #("description", json.string(option.unwrap(item.description, ""))),
    #("status", json.string(item.status)),
    #("created_at", timestamp_to_json(item.created_at)),
    #("updated_at", timestamp_to_json(item.updated_at)),
  ])
}

fn middleware(req: Request, handler: fn(Request) -> Response) -> Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use req <- wisp.csrf_known_header_protection(req)

  handler(req)
}

fn delete_todo_handler(_id: String) {
  wisp.no_content()
}

fn get_todo_handler(id: String) {
  wisp.string_body(wisp.ok(), "Todo item " <> id)
}

fn todo_handler(req: Request, id: String) -> Response {
  case req.method {
    http.Get -> get_todo_handler(id)
    http.Delete -> delete_todo_handler(id)
    _ -> wisp.method_not_allowed([http.Get, http.Delete])
  }
}

fn get_todos_hander() {
  let todo_items = [
    TodoItem(
      uuid.v4(),
      "todoitem1",
      option.Some("description 1"),
      "pending",
      timestamp.from_unix_seconds(1_766_689_000),
      timestamp.from_unix_seconds(1_766_689_000),
    ),
    TodoItem(
      uuid.v4(),
      "todoitem2",
      option.None,
      "completed",
      timestamp.from_unix_seconds(1_766_689_000),
      timestamp.from_unix_seconds(1_766_689_000),
    ),
  ]

  json.array(todo_items, todo_item_to_json)
  |> json.to_string
  |> wisp.json_response(200)
}

fn post_todos_handler(req: Request) {
  use json <- wisp.require_json(req)

  let result = {
    let decoder = {
      use title <- decode.field("title", decode.string)
      use description <- decode.optional_field("description", "", decode.string)
      decode.success(#(title, description))
    }
    use #(title, description) <- result.try(decode.run(json, decoder))

    let todo_item =
      TodoItem(
        uuid.v4(),
        title,
        option.Some(description),
        "pending",
        timestamp.from_unix_seconds(1_766_689_000),
        timestamp.from_unix_seconds(1_766_689_000),
      )

    Ok(
      todo_item_to_json(todo_item)
      |> json.to_string
      |> wisp.json_response(200),
    )
  }

  case result {
    Ok(resp) -> resp
    Error(_) -> wisp.unprocessable_content()
  }
}

fn todos_handler(req: Request) -> Response {
  case req.method {
    http.Get -> get_todos_hander()
    http.Post -> post_todos_handler(req)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

fn handler(req: Request) -> Response {
  use req <- middleware(req)

  case wisp.path_segments(req) {
    ["todos"] -> todos_handler(req)
    ["todos", id] -> todo_handler(req, id)
    _ -> wisp.not_found()
  }
}

pub fn main() -> Nil {
  wisp.configure_logger()

  let secret =
    result.unwrap(envoy.get("SECRET_KEY_BASE"), "wisp_secret_fallback")

  let assert Ok(_) =
    wisp_mist.handler(handler, secret)
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}
