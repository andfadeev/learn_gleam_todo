insert into todo_items (title, description, status)
values ($1, $2, $3)
returning *;
