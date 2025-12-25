import envoy
import gleam/erlang/process
import gleam/http
import gleam/result
import mist
import wisp.{type Request, type Response}
import wisp/wisp_mist

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
  wisp.string_body(wisp.ok(), "Todo items")
}

fn post_todos_hander() {
  wisp.created()
}

fn todos_handler(req: Request) -> Response {
  case req.method {
    http.Get -> get_todos_hander()
    http.Post -> post_todos_hander()
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
