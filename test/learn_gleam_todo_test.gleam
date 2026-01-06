import gleam/http

import gleeunit
import learn_gleam_todo.{handler2}
import wisp/simulate

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  let name = "Joe"
  let greeting = "Hello, " <> name <> "!"

  assert greeting == "Hello, Joe!"
}

pub fn wisp_endpoint_test() {
  let response = handler2(simulate.browser_request(http.Get, "/hello"))

  assert response.status == 200
  assert simulate.read_body(response) == "{\"message\":\"Hello, world!\"}"
  assert response.headers
    == [#("content-type", "application/json; charset=utf-8")]
}
