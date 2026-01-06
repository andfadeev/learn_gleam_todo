import envoy
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp
import lustre/attribute as attr
import lustre/element
import lustre/element/html
import mist
import pog
import sql
import wisp.{type Request, type Response}
import wisp/wisp_mist
import youid/uuid

pub type Context {
  Context(db: pog.Connection)
}

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

fn delete_todo_handler(ctx: Context, id: String) {
  case uuid.from_string(id) {
    Ok(id) -> {
      case sql.delete_todo_item(ctx.db, id) {
        Ok(_) -> wisp.no_content()
        Error(_) -> wisp.internal_server_error()
      }
    }
    Error(_) -> wisp.bad_request("Invalid id")
  }
}

fn get_todo_handler(ctx: Context, id: String) {
  case uuid.from_string(id) {
    Ok(id) -> {
      case sql.find_todo_item(ctx.db, id) {
        Ok(todo_item) -> {
          case todo_item.rows {
            [] -> wisp.not_found()
            [row] -> {
              let todo_item =
                TodoItem(
                  row.id,
                  row.title,
                  row.description,
                  row.status,
                  row.created_at,
                  row.updated_at,
                )

              todo_item_to_json(todo_item)
              |> json.to_string
              |> wisp.json_response(200)
            }
            _ -> {
              wisp.internal_server_error()
            }
          }
        }
        Error(_) -> wisp.internal_server_error()
      }
    }
    Error(_) -> wisp.bad_request("Invalid id")
  }
}

fn todo_handler(req: Request, ctx: Context, id: String) -> Response {
  case req.method {
    http.Get -> get_todo_handler(ctx, id)
    http.Delete -> delete_todo_handler(ctx, id)
    _ -> wisp.method_not_allowed([http.Get, http.Delete])
  }
}

fn get_todos_hander(ctx: Context) {
  case sql.find_todo_items(ctx.db) {
    Ok(todo_items) -> {
      todo_items.rows
      |> list.map(fn(row: sql.FindTodoItemsRow) {
        TodoItem(
          row.id,
          row.title,
          row.description,
          row.status,
          row.created_at,
          row.updated_at,
        )
      })
      |> json.array(todo_item_to_json)
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) -> {
      wisp.internal_server_error()
    }
  }
}

fn post_todos_handler(req: Request, ctx: Context) {
  use json <- wisp.require_json(req)

  let result = {
    let decoder = {
      use title <- decode.field("title", decode.string)
      use description <- decode.optional_field("description", "", decode.string)
      decode.success(#(title, description))
    }
    use #(title, description) <- result.try(decode.run(json, decoder))

    case sql.insert_todo_item(ctx.db, title, description, "pending") {
      Ok(r) -> {
        case r.rows {
          [row] -> {
            TodoItem(
              row.id,
              row.title,
              row.description,
              row.status,
              row.created_at,
              row.updated_at,
            )
            |> todo_item_to_json()
            |> json.to_string
            |> wisp.json_response(200)
            |> Ok()
          }
          _ -> Ok(wisp.internal_server_error())
        }
      }
      Error(_) -> {
        Ok(wisp.internal_server_error())
      }
    }
  }

  case result {
    Ok(resp) -> resp
    Error(_) -> wisp.unprocessable_content()
  }
}

fn todos_handler(req: Request, ctx: Context) -> Response {
  case req.method {
    http.Get -> get_todos_hander(ctx)
    http.Post -> post_todos_handler(req, ctx)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

fn todo_item_component(item: TodoItem) {
  html.div([attr.class("rounded border mt-4 p-4")], [
    html.h2([], [html.text(item.title)]),
    html.p([], [html.text(option.unwrap(item.description, ""))]),
  ])
}

fn get_index_handler(req: Request, context: Context) -> Response {
  use <- wisp.require_method(req, http.Get)

  case sql.find_todo_items(context.db) {
    Ok(todo_items) -> {
      let todo_items_html =
        todo_items.rows
        |> list.map(fn(i: sql.FindTodoItemsRow) {
          TodoItem(
            i.id,
            i.title,
            i.description,
            i.status,
            i.created_at,
            i.updated_at,
          )
        })
        |> list.map(todo_item_component)
      let html =
        html.html([], [
          html.head([], [
            html.title([], "Gleam todo items"),
            html.script([attr.src("https://cdn.tailwindcss.com")], ""),
          ]),
          html.body([attr.class("max-w-2xl mx-auto")], [
            html.h1([attr.class("text-red-800 font-bold")], [
              html.text("Todo: " <> int.to_string(list.length(todo_items_html))),
            ]),
            html.div([attr.class("text-blue-800")], todo_items_html),
          ]),
        ])

      wisp.ok()
      |> wisp.html_body(element.to_document_string(html))
    }
    Error(_) -> {
      wisp.internal_server_error()
    }
  }
}

pub fn handler2(req: Request) -> Response {
  use req <- middleware(req)

  case wisp.path_segments(req) {
    ["hello"] -> {
      let body =
        json.object([#("message", json.string("Hello, world!"))])
        |> json.to_string()
      wisp.json_response(body, 200)
    }

    _ -> wisp.not_found()
  }
}

pub fn handler(req: Request, ctx: Context) -> Response {
  use req <- middleware(req)

  case wisp.path_segments(req) {
    [] -> get_index_handler(req, ctx)
    ["hello"] -> {
      let body =
        json.object([#("message", json.string("Hello, world!"))])
        |> json.to_string()
      wisp.json_response(body, 200)
    }
    ["todos"] -> todos_handler(req, ctx)
    ["todos", id] -> todo_handler(req, ctx, id)
    _ -> wisp.not_found()
  }
}

pub fn main() -> Nil {
  wisp.configure_logger()

  let secret =
    result.unwrap(envoy.get("SECRET_KEY_BASE"), "wisp_secret_fallback")

  let db_pool_name = process.new_name("db_pool")
  let assert Ok(database_url) = envoy.get("DATABASE_URL")
  let assert Ok(pog_config) = pog.url_config(db_pool_name, database_url)
  let assert Ok(_) =
    pog_config
    |> pog.pool_size(10)
    |> pog.start

  let con = pog.named_connection(db_pool_name)

  let context = Context(con)
  let handler = handler(_, context)

  let assert Ok(_) =
    wisp_mist.handler(handler, secret)
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}
