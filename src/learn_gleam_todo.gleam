import envoy
import gleam/erlang/process
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

fn handler(req: Request) -> Response {
  use _ <- middleware(req)

  wisp.ok()
  |> wisp.string_body("Hellow from Wisp & Gleam")
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
