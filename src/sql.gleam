//// This module contains the code to run the sql queries defined in
//// `./src/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import pog
import youid/uuid.{type Uuid}

/// Runs the `delete_todo_item` query
/// defined in `./src/sql/delete_todo_item.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_todo_item(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "delete from todo_items
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `find_todo_item` query
/// defined in `./src/sql/find_todo_item.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindTodoItemRow {
  FindTodoItemRow(
    id: Uuid,
    title: String,
    description: Option(String),
    status: String,
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

/// Runs the `find_todo_item` query
/// defined in `./src/sql/find_todo_item.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_todo_item(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(FindTodoItemRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use title <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use status <- decode.field(3, decode.string)
    use created_at <- decode.field(4, pog.timestamp_decoder())
    use updated_at <- decode.field(5, pog.timestamp_decoder())
    decode.success(FindTodoItemRow(
      id:,
      title:,
      description:,
      status:,
      created_at:,
      updated_at:,
    ))
  }

  "select * from todo_items
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `find_todo_items` query
/// defined in `./src/sql/find_todo_items.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindTodoItemsRow {
  FindTodoItemsRow(
    id: Uuid,
    title: String,
    description: Option(String),
    status: String,
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

/// Runs the `find_todo_items` query
/// defined in `./src/sql/find_todo_items.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_todo_items(
  db: pog.Connection,
) -> Result(pog.Returned(FindTodoItemsRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use title <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use status <- decode.field(3, decode.string)
    use created_at <- decode.field(4, pog.timestamp_decoder())
    use updated_at <- decode.field(5, pog.timestamp_decoder())
    decode.success(FindTodoItemsRow(
      id:,
      title:,
      description:,
      status:,
      created_at:,
      updated_at:,
    ))
  }

  "select * from todo_items;
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `insert_todo_item` query
/// defined in `./src/sql/insert_todo_item.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type InsertTodoItemRow {
  InsertTodoItemRow(
    id: Uuid,
    title: String,
    description: Option(String),
    status: String,
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

/// Runs the `insert_todo_item` query
/// defined in `./src/sql/insert_todo_item.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_todo_item(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
) -> Result(pog.Returned(InsertTodoItemRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use title <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use status <- decode.field(3, decode.string)
    use created_at <- decode.field(4, pog.timestamp_decoder())
    use updated_at <- decode.field(5, pog.timestamp_decoder())
    decode.success(InsertTodoItemRow(
      id:,
      title:,
      description:,
      status:,
      created_at:,
      updated_at:,
    ))
  }

  "insert into todo_items (title, description, status)
values ($1, $2, $3)
returning *;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

// --- Encoding/decoding utils -------------------------------------------------

/// A decoder to decode `Uuid`s coming from a Postgres query.
///
fn uuid_decoder() {
  use bit_array <- decode.then(decode.bit_array)
  case uuid.from_bit_array(bit_array) {
    Ok(uuid) -> decode.success(uuid)
    Error(_) -> decode.failure(uuid.v7(), "Uuid")
  }
}
