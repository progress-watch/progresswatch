# Progress Watch

Universal progress tracker for any process. A script, crawler, CI job or AI agent
reports its progress with a single HTTP request; you watch it on your phone and get
a push notification when it finishes.

This repository is the server. There is also a [CLI](https://github.com/progress-watch/progresswatch-cli)
and a mobile app.

- **Domain:** [progress.watch](https://progress.watch)
- **License:** [AGPL-3.0](LICENSE)

---

## Self-hosting in one command

```bash
git clone https://github.com/progress-watch/progresswatch.git
cd progresswatch
docker compose up
```

That is the whole thing: the API on `http://localhost:3000`, a Sidekiq worker, Redis,
and a SQLite database on a named volume. Set `PORT` to serve somewhere other than 3000.

Open `http://localhost:3000` and create a space — that is the whole setup. The dashboard
shows every task in the space live, and the **Connect** menu gives you ready-to-paste
snippets for the CLI, curl, an agent skill and Docker, with your space UUID already
filled in.

Check it is alive:

```bash
curl http://localhost:3000/up
# {"status":"ok","database":true,"redis":true}
```

### MULTITENANT

Unset, which is the default, is a self-hosted install: no about page in the navbar, every
page `noindex`, `robots.txt` disallowing everything, and `/sitemap.xml` answering 404.
There is no audience to reach from somebody's own box, and nothing there that wants to be
found in a search.

`MULTITENANT=true` is the hosted deployment and turns all of that on.

### Sweeping empty spaces

Opening the site creates a space for you, so plenty get created and never used —
including by anything that crawls the page. A space that has **ever** held a task is kept
for good, however long nobody looks at it. Only ones that never held a single task are
swept, and only once they are more than 30 days old.

Nothing runs on a timer, so 30 days is a floor rather than a schedule: run this daily and
empty spaces go the day they qualify, run it once a year and they sit until then. Either
way what a user can be promised is only that past 30 days an empty space may disappear.

**Nothing runs it for you.** Schedule it however you already schedule things:

```bash
bin/rails sweep_empty_spaces
```

```
# crontab, daily at 04:17
17 4 * * * cd /path/to/progresswatch && bin/rails sweep_empty_spaces
```

With Docker, the same command through `docker compose exec app`. Skipping it is safe for
your data — nothing is deleted that should not be — it just means the table grows with
spaces nobody ever used.

Losing the volume is recoverable, not catastrophic. Spaces and task structure are
gone, but you create a new space and your reporting processes repopulate everything on
their next request. Nothing on that volume is irreplaceable, which is the point.

---

## Concepts

### Space

A container for tasks, identified by a UUID. **The UUID is the credential** — whoever
knows it can read and write the space. There are no accounts, no login and no
passwords. Sharing a space means giving someone the UUID; treat it like one.

### Task

Belongs to a space, identified by a UUID. Progress is reported as `start` / `end` /
`current`, **not** a percentage, because `1200 / 50000 pages` tells you something and
`2.4%` does not. `end` may change mid-flight — a crawler that discovers more URLs just
sends a bigger number and the bar recalculates.

`values` is a free-form flat object for everything else: `{"pages": 1200, "errors": 3,
"rate": "45/s", "log": "Timeout on /foo, retrying"}`. The client decides how to render
each key. A `log` key holds the *last* line, not a history.

### Nesting

Exactly one level. A task is either top-level or a child; a child cannot have children,
and a `parent_uuid` pointing at a task that already has a parent is rejected. A parent's
progress aggregates from its children.

---

## HTTP API

Six endpoints, and the surface is meant to stay this small.

| | |
|---|---|
| `POST /spaces` | create a space |
| `POST /spaces/:space_uuid/tasks` | create a task, returns its uuid |
| `PUT /tasks/:task_uuid` | overwrite task state |
| `GET /spaces/:space_uuid` | every task in the space with current state |
| `GET /tasks/:task_uuid` | one task with its children |
| `POST /mcp/:space_uuid` | MCP over Streamable HTTP |
| `GET /up` | health check |

### Create a space

```bash
curl -X POST http://localhost:3000/spaces \
  -H 'Content-Type: application/json' \
  -d '{"title": "Production"}'
```

```json
{ "uuid": "406d45fd-f623-472a-acac-eef9b5281549", "title": "Production" }
```

### Create a task

```bash
curl -X POST http://localhost:3000/spaces/406d45fd-.../tasks \
  -H 'Content-Type: application/json' \
  -d '{"title": "Crawl docs", "source": "crawler.py"}'
```

```json
{ "uuid": "fee462f1-cd51-43ce-b4e1-c2d61687734a" }
```

Pass `parent_uuid` to make it a child of another task.

### Report progress

```bash
curl -X PUT http://localhost:3000/tasks/fee462f1-... \
  -H 'Content-Type: application/json' \
  -d '{"current": 1200, "end": 50000, "values": {"pages": 1200, "errors": 3}}'
```

Every request **fully overwrites** the task's state. There is no merging — see below.

Mark a task finished explicitly, whatever the numbers say:

```bash
curl -X PUT http://localhost:3000/tasks/fee462f1-... \
  -H 'Content-Type: application/json' \
  -d '{"done": true}'
```

### Read a space

```bash
curl http://localhost:3000/spaces/406d45fd-...
```

```json
{
  "uuid": "406d45fd-f623-472a-acac-eef9b5281549",
  "title": "Production",
  "tasks": [
    {
      "uuid": "fee462f1-...",
      "space_uuid": "406d45fd-...",
      "parent_uuid": null,
      "title": "Deploy",
      "source": "ci",
      "created_at": "2026-08-02T12:56:07Z",
      "finished_at": null,
      "duration": null,
      "progress": {
        "current": 1, "end": 2, "ratio": 0.6,
        "values": {}, "updated_at": "2026-08-02T12:56:08Z",
        "aggregated": true
      },
      "children": [
        { "uuid": "06b1301b-...", "title": "Build", "finished_at": "2026-08-02T12:56:08Z",
          "progress": { "current": 100, "end": 100, "ratio": 1.0, "values": {},
                        "updated_at": "2026-08-02T12:56:08Z", "aggregated": false },
          "children": [] }
      ]
    }
  ]
}
```

### Read one task

```bash
curl http://localhost:3000/tasks/fee462f1-...
```

Same shape as a single entry above, with its children nested.

---

### MCP

Agents can report progress without you writing any glue:

```bash
claude mcp add --transport http progress-watch https://progress.watch/mcp/406d45fd-...
```

Four tools — `create_space`, `create_task`, `update_task`, `complete_task` — hitting the
same code as the endpoints above. The agent decides when to create a task and how often to
report; the tool descriptions tell it when tracking is worth the trouble and that nesting
is one level.

`create_space` exists so an agent that connects without one is not stuck: it creates a
space and hands back the URL for you to open. `create_task` takes an optional `space_uuid`
to use it; the rest need only a task uuid, which already knows its space.

The space UUID can travel in the path (above) or in an `X-Space-Uuid` header, for clients
that only accept a bare URL. This server is stateless: it issues no `Mcp-Session-Id` and
answers with `application/json` rather than opening an SSE stream.

---

## Semantics worth knowing before you build on this

### A write replaces the whole state

`PUT` is not a patch. If a request omits `values`, the stored `values` is **cleared**,
not preserved. Same for `current` and `end`. `PATCH` on the same path is refused with a
405 rather than quietly behaving like `PUT`, because it would promise a merge that never
happens.

```bash
curl -X PUT .../tasks/$T -d '{"current": 10, "end": 100, "values": {"pages": 10}}'
curl -X PUT .../tasks/$T -d '{"current": 20, "end": 100}'
# values is now {} — not {"pages": 10}
```

This is deliberate. The reporting process always knows its own complete state, so
sending everything each time is simpler than tracking what it has already sent — and
one request fully restores a task after a server restart.

### `"progress": null` is not zero

A task at 0% and a task that has never reported are different things, and the API keeps
them apart:

| response | meaning | render as |
|---|---|---|
| `"progress": null` | nothing in Redis — expired, flushed, or the server restarted | "Waiting for data…" |
| `"progress": {"current": 0, ...}` | the process reported zero | an empty bar |

Progress is volatile by design (see below), so `null` is a normal state and not an
error. The task keeps its title, parent and children throughout; the next write from
the reporting process restores everything.

### Parent progress is derived

When a task has children, its own `current`/`end` are ignored and `"aggregated": true`:

- `ratio` — the mean of its children's ratios, the number to drive a smooth bar with
- `current` / `end` — finished children out of total, the honest raw numbers ("2 of 5 steps")
- `values` — still the parent's own, so it can carry a log line of its own

A child that has reported nothing counts as zero (it has not started). A child that
finished counts as complete even if Redis has since forgotten it, because `finished_at`
is on disk. A task with no children uses its own reported values.

`end` of zero or missing means the denominator is unknown, so `ratio` is `null` rather
than a division by zero, and the task will not auto-complete.

### Completion

A task completes when `current >= end` (with `end` greater than zero) or when `done: true`
is sent. On completion the server writes `finished_at` and `duration` — one UPDATE for
the whole life of the task — and enqueues the push notification.

Completing is one-way. Reporting again afterwards still overwrites progress, but
`finished_at` does not move and no second notification is sent.

---

## Storage model

The most important design decision here: **progress is never written to disk.**

| Data | Where | Write pattern |
|---|---|---|
| `current`, `end`, `values` | Redis | overwritten on every request, TTL on inactivity |
| Spaces | database | INSERT once, then basically never |
| Task structure (uuid, space, parent, title, source) | database | INSERT once at creation |
| Completion (`finished_at`, `duration`) | database | one UPDATE when the task completes |

A crawler reporting every second for three months must not grow the database. That is
what makes this cheap enough to run at the target price: a task is a few hundred bytes
in Redis and the database stays tiny forever.

Redis is the source of truth for progress and **may be empty** — it is TTL'd, it can be
flushed, and a managed Redis can fail over and lose keys. The database still knows the
space, the task, its title and its parent, so the API keeps answering and clients render
"Waiting for data…". This is expected behaviour, not a failure mode to engineer around.

Redis has two unrelated jobs and they are kept apart: task state on logical database 0
under the `pw:progress:` prefix, the Sidekiq queue on database 1. Flushing stale progress
can never take the queue with it, and the two can be pointed at different instances.

### Two database adapters

**SQLite for self-hosted, PostgreSQL for cloud** — one codebase, one set of migrations,
selected by `DATABASE_URL`. CI runs the whole suite against both.

This is affordable only because the storage model is so thin: two tables, primary-key
lookups, INSERT-mostly. It imposes one rule — **no adapter-specific features.** No JSONB,
no arrays, no `gen_random_uuid()`, no Postgres-only index types. UUIDs are generated in
Ruby and stored as strings, timestamps are plain datetimes. If something can only be
expressed in one adapter, the design has drifted.

---

## Configuration

Everything is an environment variable. There are no encrypted credentials in this repo
and no config files to edit — the same image runs on a home NAS and in the cloud.

| Variable | Default | |
|---|---|---|
| `DATABASE_URL` | `sqlite3:storage/production.sqlite3` | `postgresql://…` for cloud |
| `REDIS_URL` | `redis://localhost:6379` | base URL, split into two logical databases |
| `PROGRESS_REDIS_URL` | `REDIS_URL` db 0 | override to use a separate instance |
| `SIDEKIQ_REDIS_URL` | `REDIS_URL` db 1 | override to use a separate instance |
| `PROGRESS_TTL_SECONDS` | `86400` | abandoned tasks expire; refreshed on every write |
| `PROGRESS_KEY_PREFIX` | `pw:progress` | |
| `SECRET_KEY_BASE` | — | required in production |
| `PORT` | `3000` | |
| `RAILS_MAX_THREADS` | `5` | also sizes both connection pools |
| `WEB_CONCURRENCY` | `0` | Puma workers; leave at 0 for a small box |
| `SIDEKIQ_CONCURRENCY` | `5` | |
| `FORCE_SSL` | `false` | set `true` behind a TLS-terminating proxy; also drives `assume_ssl`, so leaving it off keeps redirects on plain HTTP |
| `PUSH_CONTENT` | `full` | `minimal` sends no task title — see below |
| `RAILS_LOG_LEVEL` | `info` | |

### Notification content and privacy

Push notifications are **not** end-to-end encrypted yet. A self-hosted server has no
FCM/APNs credentials of its own, so it forwards notifications through a relay on
progress.watch — which means **your task titles pass through a third party in the clear**
on their way to Apple and Google.

Self-hosters are exactly the audience that will assume otherwise, so: that is the
trade, stated upfront. If you cannot accept it, set `PUSH_CONTENT=minimal` and
notifications become "Task completed" with nothing identifying in them. You lose most of
their usefulness, which is the honest cost.

The relay forwards and forgets: no persistence of payloads beyond what delivery
requires, and metadata-only logging. Encryption is on the roadmap — it is deferred
because doing it on iOS requires a Notification Service Extension and a custom dev
client, which is a large cost landing on the most expensive part of the project.

---

## Cloud deployment

The same image, configured differently. Nothing in the application knows it is on any
particular cloud, and that is a property worth keeping:

- **Stateless containers.** No local disk writes outside the SQLite volume, no
  in-process caches holding task state. Redis is the shared store precisely so any
  container can serve any request.
- **Horizontal scaling.** Several app containers run at once; nothing assumes a single
  process.
- `GET /up` for the load balancer — it checks the database and Redis, so a box with a
  dead Redis is pulled from rotation instead of answering every poll with a 500.
- Structured JSON logs to stdout, no log files.
- Graceful SIGTERM in both Puma and Sidekiq, inside a 25-second drain deadline.

---

## Development

Requires Ruby 4.0.5 (see `.tool-versions`), Node 22, and a local Redis.

```bash
bundle install
npm install
bin/rails db:prepare
bin/dev
```

`bin/dev` runs everything in `Procfile.dev` under foreman (installing it if missing): the
server on port 3000, a webpack watcher, and Sidekiq — without the worker, completion
notifications never fire locally. Set `PW_PORT` to move the server; plain `PORT` will not
work, because foreman assigns its own to every process.

To run just the server, build the assets once first — the layout renders
`javascript_pack_tag`, which needs a manifest to look up:

```bash
./bin/shakapacker
bin/rails server
```

The specs need that manifest too.

Tests:

```bash
bundle exec rspec

# against PostgreSQL, exactly as CI does it
DATABASE_URL=postgresql:///progresswatch_test RAILS_ENV=test bin/rails db:prepare
DATABASE_URL=postgresql:///progresswatch_test RAILS_ENV=test bundle exec rspec
```

The suite uses Redis logical database 15 and flushes it between examples. It will not
touch a development server's data.

Style is enforced by RuboCop and CI fails on offences:

```bash
bundle exec rubocop
```

### How the code is organised

Anything that writes, orchestrates or has a side effect is a **command object** — a plain
module with `module_function` and a `call`, under `lib/<domain>/<verb>.rb`:

```
lib/spaces/create.rb             Spaces::Create.call(title:)
lib/spaces/serialize_for_api.rb  Spaces::SerializeForApi.call(space)
lib/tasks/create.rb              Tasks::Create.call(space:, title:, ...)
lib/tasks/report.rb              Tasks::Report.call(task, current:, end_value:, ...)
lib/tasks/serialize_for_api.rb   Tasks::SerializeForApi.call(task)
lib/task_states.rb               Every Redis read and write for progress
lib/push_delivery.rb             The seam where FCM/APNs will plug in
```

Models hold structure only — associations, validations, `attribute` defaults. No
persistence orchestration, no enqueuing, nothing reaching another service. Controllers
find the record, call a command object and render. MCP routes are coming and will call
those same command objects, which is why the logic sits in neither of the other layers.

Redis is reached only through `TaskStates`. If you need `ProgressWatch::PROGRESS_REDIS`
somewhere else, add a method there instead.

**One trap worth knowing before your first commit:** the domain here is called `Task`, and
Rails normally excludes `lib/tasks` from autoloading because that is where rake files go.
This app therefore sets `config.autoload_lib(ignore: %w[assets])` so `lib/tasks/create.rb`
loads as `Tasks::Create`. Rake files are `.rake` and Zeitwerk skips them, but dropping a
`.rb` helper into `lib/tasks` will break booting.

There is no `config/master.key` and no `credentials.yml.enc`, deliberately — a self-hoster
cannot have our key, so every setting is an environment variable. Do not run
`rails credentials:edit`; it bakes a key into the image and breaks the container.

---

## Things deliberately not built

Listed so they do not get reintroduced as obvious improvements:

- **Bidirectional communication.** The app is a read-only dashboard, like an airport
  departures board. Approve/reject buttons and agent commands would make this an
  orchestrator — a different product with an order of magnitude more complexity.
- **Progress history / time series.** Only the latest state exists.
- **Log history.** Only the last line, in `values.log`.
- **Merging partial updates.** Full overwrite only.
- **Nesting beyond one level.**
- **A separate `stages` concept.** Parent/children already covers it.
- **Accounts, auth, roles, permissions.** The UUID is the credential.
