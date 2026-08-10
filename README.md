<h1 align="center" style="border-bottom: none">
  <div>
    <a href="https://progress.watch">
      <img alt="Progress Watch" src="public/icons/icon-192.png" width="80" />
      <br>
    </a>
    Progress Watch
  </div>
</h1>
<h3 align="center">
  Open source progress tracking for anything that runs without you
</h3>
<p>
A nightly crawl, a training run, a migration, a CI pipeline, an AI agent working through a long task — they all run for hours with nobody watching. Progress Watch gives them one place to report to, one place for you to look, and a push notification when they finish.
</p>
<p>
This repository is the server. The command line client is <a href="https://github.com/progress-watch/progresswatch-cli">progresswatch-cli</a>.
</p>
<h2 align="center">
  <a href="https://progress.watch">☁️ Hosted</a>
  <span>|</span>
  <a href="https://progress.watch/docs">📖 Documentation</a>
</h2>

## Features

- [CLI](https://github.com/progress-watch/progresswatch-cli) for a shell or a CI job — create a task, report counts against it, close it
- MCP server and an agent skill, so an AI agent reports its own work as it goes
- Or one HTTP request from anything else — no SDK, no library, and the whole API as OpenAPI 3.1
- Counts rather than percentages — `1200 / 50000 pages` says something `2.4%` does not
- Steps: one level of nesting, and a job's bar averages them
- Live dashboard in the browser, no page to refresh
- Web Push when something finishes, on desktop and phone, with nothing to register with Apple or Google
- No accounts, no login, no passwords — a space UUID is the credential
- Progress is never written to the database, so it stays tiny however long anything runs
- SQLite or PostgreSQL from one image

## Deploy

|Render|DigitalOcean|Railway|
|:--:|:--:|:--:|
| [<img alt="Deploy to Render" src="https://render.com/images/deploy-to-render-button.svg" height="40">](https://render.com/deploy?repo=https://github.com/progress-watch/progresswatch) | [<img alt="Deploy to DigitalOcean" src="https://www.deploytodo.com/do-btn-blue.svg" height="40">](https://cloud.digitalocean.com/apps/new?repo=https://github.com/progress-watch/progresswatch/tree/master) | [<img alt="Deploy on Railway" src="https://railway.com/button.svg" height="40">](https://railway.com/deploy/REPLACE-ME) |

Render and DigitalOcean read a spec from this repository — `render.yaml` and `.do/deploy.template.yaml` — so each button creates the app, the worker, a Redis and a Postgres in one pass, with nothing to fork and nothing to keep in step. Railway is the exception: its button resolves a template held in Railway rather than a file here.

They are the convenient option rather than the cheap one: four billable components on a managed platform is several times the same thing as `docker compose up` on the smallest VPS anyone sells.

#### Docker Compose

Save this as `docker-compose.yml`. It runs the published image, so there is nothing to clone and nothing to build:

```yaml
# Progress Watch. Everything is an environment variable, and the whole list — Postgres,
# notifications, TLS, process sizing — is at https://progress.watch/docs/environment-variables
services:
  progresswatch:
    image: progresswatch/progresswatch:latest
    container_name: progresswatch
    restart: unless-stopped
    ports:
      - 7979:3000
    volumes:
      - storage:/rails/storage
    environment:
      - SECRET_KEY_BASE=replace-me-with-openssl-rand-hex-64
      - DATABASE_URL=sqlite3:storage/production.sqlite3?timeout=5000
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis

  # Sends the notifications and does nothing else. Whatever you add above, add here too:
  # a VAPID key set on one and not the other renders the button and never delivers.
  progresswatch-worker:
    image: progresswatch/progresswatch:latest
    container_name: progresswatch-worker
    restart: unless-stopped
    command: bundle exec sidekiq -C config/sidekiq.yml
    volumes:
      - storage:/rails/storage
    environment:
      - SECRET_KEY_BASE=replace-me-with-openssl-rand-hex-64
      - DATABASE_URL=sqlite3:storage/production.sqlite3?timeout=5000
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis

  redis:
    image: redis:8-alpine
    container_name: progresswatch-redis
    restart: unless-stopped
    # No persistence: progress is volatile by design, and a restart costs one
    # "Waiting for data..." cycle.
    command: redis-server --save "" --appendonly no

volumes:
  storage:
```

Replace the placeholder secret in both services, then start it:

```sh
openssl rand -hex 64
docker compose up -d
```

The app on `http://localhost:7979`, a worker, a Redis and a SQLite file on a named volume. Open it, create a space, and the Connect menu on that space gives you snippets with its UUID already in them.

That file is the only place anything is configured — Postgres, the published port and the notification keys are all lines in an `environment:` block, and both services want the same ones. [Environment variables](https://progress.watch/docs/environment-variables) is the full list.

```sh
curl http://localhost:7979/up
# {"status":"ok","database":true,"redis":true}
```

## Reporting into it

```sh
npm install -g progresswatch
progresswatch space new "My work"

TASK=$(progresswatch new "Crawl docs")
progresswatch update $TASK --current 1200 --end 50000 --values pages=1200
progresswatch done $TASK
```

Three commands, and the middle one is the one that goes in your loop — it is where `1200 / 50000 pages` comes from rather than a bar with no numbers on it. Every write replaces the whole state, so send all of it each time; there is no merging.

When the process is not yours to change, wrap it whole:

```sh
progresswatch run "python train.py"
```

`run` creates the task, passes the command's output through untouched and closes it with the exit code, so a job that fails notifies too. It reports start and finish, not counts — nothing outside the process knows how far along it is.

Underneath every one of these is a single request, so an AI agent connects over [MCP](https://progress.watch/docs/mcp) and anything else calls the [HTTP API](https://progress.watch/docs/api) directly.

## Documentation

- [Get started](https://progress.watch/docs) — what it is and what it will not do
- [CLI](https://progress.watch/docs/cli) · [Agent skill](https://progress.watch/docs/agent) · [MCP](https://progress.watch/docs/mcp) · [curl](https://progress.watch/docs/curl)
- [API Reference](https://progress.watch/docs/api) — every endpoint, with a sample in eight languages
- [Self-hosting](https://progress.watch/docs/self-hosting) — what runs, what to configure, what to put on a cron
- [Notifications](https://progress.watch/docs/notifications) — Web Push, and what has to happen on a phone
- [Environment variables](https://progress.watch/docs/environment-variables) — everything you can set

## Development

Ruby 4.0.5 (see `.tool-versions`), Node 22, and a local Redis.

```sh
bundle install
npm install
bin/rails db:prepare
bin/dev
```

`bin/dev` runs the server, a webpack watcher and Sidekiq — without the worker, completion notifications never fire locally. Set `PW_PORT` to move the server; plain `PORT` will not work, because foreman assigns its own to every process. `docker compose up` runs the published image rather than your working tree, so it is not a way to try a change.

```sh
bundle exec rspec
bundle exec rubocop
```

The specs render the layout, which needs a webpack manifest — run `./bin/shakapacker` once if you have not started `bin/dev`. CI runs the suite against both SQLite and PostgreSQL, so a migration has to be clean on both.

## License

The server is [AGPL-3.0](LICENSE), because it is a network service and AGPL is what stops a modified copy being run as a competing hosted service without the changes being published. The [CLI](https://github.com/progress-watch/progresswatch-cli) is MIT — it is a client, it goes in CI scripts and Dockerfiles, and a copyleft licence there would cost adoption and protect nothing.
