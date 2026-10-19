# Todo List API

A JSON task list over HTTP, written in [Salam](https://www.salamlang.ir).
Create, filter, sort, page, complete and delete todos, with an OpenAPI 3.1
document and a browser UI generated straight from the live router.

The service is a single statically compiled binary. Tasks live in a JSON file,
every write is persisted atomically, and the store is guarded by a mutex so it
stays correct when request handling becomes concurrent.

## Features

- Full CRUD over tasks, plus dedicated `complete` and `reopen` actions.
- Filtering by status, priority, tag and free-text search over title and description.
- Sorting by `id`, `title`, `priority`, `created_at`, `updated_at` or `due_date`, ascending or descending.
- Paging with `limit` and `offset`, with the total number of matches returned.
- Input validation with field-level errors and a stable, machine-readable error body.
- Bulk delete of every completed task, and statistics across the whole list.
- OpenAPI 3.1 document and an interactive docs page served from `/docs`.
- Atomic persistence to a JSON file, reloaded on startup.
- Configuration through environment variables, no rebuild needed.

## Requirements

- Salam 0.5.6 or newer (`salam version`).
- macOS, Linux or Windows. Only the standard library is used.

## Quick start

```sh
salam run
```

The server binds to `127.0.0.1:8080`. The same thing through `make`:

```sh
make run      # salam run
make build    # compiles the ./todolist binary
make check    # checks the formatting of every file
make fmt      # rewrites every file in canonical form
make clean    # removes .salam-build and the binary
```

Point a browser at <http://127.0.0.1:8080/docs> for the interactive API
reference, or fetch the raw document at `/docs/openapi.json`.

## Configuration

Every setting has a default, so the server runs with no configuration at all.

| Variable | Default | Meaning |
| --- | --- | --- |
| `TODOLIST_HOST` | `127.0.0.1` | address the server binds to |
| `TODOLIST_PORT` | `8080` | TCP port |
| `TODOLIST_DATA_FILE` | `data/tasks.json` | where the tasks are stored |
| `TODOLIST_API_PREFIX` | `/api/v1` | prefix of every task route |
| `TODOLIST_DOCS_PREFIX` | `/docs` | prefix of the OpenAPI document and UI |
| `TODOLIST_ACCESS_LOG` | `true` | log one line per request |

```sh
TODOLIST_PORT=9000 TODOLIST_DATA_FILE=/var/lib/todos.json salam run
```

## Endpoints

| Method | Path | Description |
| --- | --- | --- |
| `GET` | `/health` | liveness report and the number of stored tasks |
| `GET` | `/api/v1/tasks` | list tasks, filtered, sorted and paged |
| `POST` | `/api/v1/tasks` | create a task, `201` with a `Location` header |
| `GET` | `/api/v1/tasks/stats` | counts by status, and how many are overdue |
| `DELETE` | `/api/v1/tasks/completed` | delete every completed task |
| `GET` | `/api/v1/tasks/:id` | fetch one task |
| `PUT` | `/api/v1/tasks/:id` | replace a task, every field comes from the body |
| `PATCH` | `/api/v1/tasks/:id` | change only the members present in the body |
| `DELETE` | `/api/v1/tasks/:id` | delete one task |
| `POST` | `/api/v1/tasks/:id/complete` | mark a task complete |
| `POST` | `/api/v1/tasks/:id/reopen` | open a completed task again |

### List query parameters

| Parameter | Type | Default | Notes |
| --- | --- | --- | --- |
| `status` | enum | any | `pending`, `in_progress`, `completed` |
| `priority` | enum | any | `low`, `medium`, `high`, `urgent` |
| `tag` | string | any | exact tag match |
| `q` | string | any | case-insensitive search in title and description |
| `sort` | enum | `id` | `id`, `title`, `priority`, `created_at`, `updated_at`, `due_date` |
| `order` | enum | `desc` | `asc` or `desc` |
| `limit` | integer | `20` | clamped to 1 through 100 |
| `offset` | integer | `0` | how many matches to skip |

## Examples

Create a task:

```sh
curl -i -X POST http://127.0.0.1:8080/api/v1/tasks \
  -d '{"title":"Buy milk","priority":"high","tags":["home","errand"],"due_date":"2026-01-31"}'
```

```http
HTTP/1.1 201 Created
Location: /api/v1/tasks/1
Content-Type: application/json

{"id":1,"title":"Buy milk","status":"pending","priority":"high","tags":["home","errand"],"due_date":"2026-01-31","created_at":"2026-10-19T21:16:37","updated_at":"2026-10-19T21:16:37"}
```

List the two most urgent open tasks:

```sh
curl "http://127.0.0.1:8080/api/v1/tasks?status=pending&sort=priority&order=desc&limit=2"
```

```json
{
  "total": 3,
  "limit": 2,
  "offset": 0,
  "items": [
    {"id": 2, "title": "Write report", "status": "pending", "priority": "urgent", "tags": ["work"], "created_at": "2026-10-19T21:27:14", "updated_at": "2026-10-19T21:27:14"},
    {"id": 1, "title": "Buy milk", "status": "pending", "priority": "high", "tags": ["home", "errand"], "due_date": "2026-01-31", "created_at": "2026-10-19T21:27:14", "updated_at": "2026-10-19T21:27:14"}
  ]
}
```

Change one field, complete a task, read the counts:

```sh
curl -X PATCH http://127.0.0.1:8080/api/v1/tasks/1 -d '{"priority":"urgent"}'
curl -X POST  http://127.0.0.1:8080/api/v1/tasks/1/complete
curl         http://127.0.0.1:8080/api/v1/tasks/stats
```

```json
{"total":3,"pending":2,"in_progress":0,"completed":1,"overdue":0}
```

Delete one task, or every completed one:

```sh
curl -X DELETE http://127.0.0.1:8080/api/v1/tasks/3
curl -X DELETE http://127.0.0.1:8080/api/v1/tasks/completed
```

```json
{"deleted":1}
```

## Data shapes

`Task`, as it is stored and returned:

| Field | Type | Notes |
| --- | --- | --- |
| `id` | integer | assigned by the server, never reused |
| `title` | string | required, at most 200 characters |
| `description` | string | at most 2000 characters, omitted when empty |
| `status` | string | `pending`, `in_progress` or `completed` |
| `priority` | string | `low`, `medium`, `high` or `urgent` |
| `tags` | string array | at most 20 tags, each at most 40 characters |
| `due_date` | string | `YYYY-MM-DD`, omitted when unset |
| `created_at` | string | set once, on creation |
| `updated_at` | string | set on every change |
| `completed_at` | string | set on completion, cleared on reopen, omitted while open |

A request body may carry any subset of `title`, `description`, `status`,
`priority`, `tags` and `due_date`. `POST` and `PUT` require `title`; `PATCH`
accepts any subset.

A failing request returns a problem document. Validation failures list every
field that has to be fixed:

```json
{
  "error": "validation_failed",
  "detail": "one or more fields are invalid",
  "fields": [
    {"field": "title", "message": "title is required"},
    {"field": "priority", "message": "priority must be one of low, medium, high, urgent"}
  ]
}
```

| Status | `error` | When |
| --- | --- | --- |
| `400` | `invalid_json` | the body is missing, empty or not JSON |
| `400` | `invalid_id` | the id in the path is not a positive integer |
| `404` | `not_found` | no task has that id |
| `422` | `validation_failed` | a field is missing or malformed |

## Project layout

```
salam.salam          entry point: configuration, store, router, docs, server
src/config.salam     environment backed settings
src/model.salam      Task and TaskInput, status and priority vocabulary
src/apierr.salam     problem documents and field issues
src/request.salam    reading members out of a JSON body
src/validate.salam   the validation rules
src/store.salam      the task store, mutex guarded, atomic JSON persistence
src/service.salam    filtering, sorting, paging and the use cases
src/handlers.salam   HTTP handlers, one function per route
src/routes.salam     the route table
src/docs.salam       the OpenAPI document, built from the live router
```

The layers only point one way: handlers call the service, the service calls the
store and the validator, and nothing below the handlers knows about HTTP.

## Notes

- Salam keywords exist in English and Persian. This project is written in English
  Salam, which is what `salam run` compiles by default.
- The store owns the tags vector of every stored task; values handed out by
  `Snapshot` and `Find` borrow those tags, so callers never free them.

## License

MIT. See [LICENSE](LICENSE). Copyright (c) 2026 Seyyed Ali Mohammadiyeh.
