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
| [<img alt="Deploy to Render" src="https://render.com/images/deploy-to-render-button.svg" height="40">](https://render.com/deploy?repo=https://github.com/progress-watch/progresswatch) | [<img alt="Deploy to DigitalOcean" src="https://www.deploytodo.com/do-btn-blue.svg" height="40">](https://cloud.digitalocean.com/apps/new?repo=https://github.com/progress-watch/progresswatch/tree/master) | [<img alt="Deploy on Railway" src="https://railway.com/button.svg" height="40">](https://railway.com/deploy/progress-watch?referralCode=P9RGBN&utm_medium=integration&utm_source=template&utm_campaign=generic) |

Each one creates the app and a Postgres in one pass, with nothing to fork. Render and DigitalOcean read their spec from this repository, `render.yaml` and `.do/deploy.template.yaml`; Railway's lives in a template that runs the published image.

They are the convenient option rather than the cheap one: paying a managed platform for each component costs several times what the same thing costs as `docker compose up` on the smallest VPS anyone sells.

#### Docker

```sh
docker run --name progresswatch -p 7979:3000 -v progresswatch:/data progresswatch/progresswatch
```

The app on `http://localhost:7979`, with Redis and SQLite inside the same container. What they keep lives on the volume, in `/data/progresswatch`: the database, a snapshot of Redis, and the secret key generated on first start. Open it, create a space, and the Connect menu on that space gives you snippets with its UUID already in them.

#### Docker Compose

```yaml
services:
  progresswatch:
    image: progresswatch/progresswatch:latest
    container_name: progresswatch
    restart: unless-stopped
    ports:
      - 7979:3000
    volumes:
      - progresswatch:/data

volumes:
  progresswatch:
```

```sh
docker compose up -d
```

Settings are environment variables, in an `environment:` block under the service or as `-e` on `docker run`; [Environment variables](https://progress.watch/docs/environment-variables) is the list. Updating is `docker compose pull` and `up -d` again, and running tasks keep their progress through it, because Redis writes its snapshot to the volume as the container stops.

```sh
curl http://localhost:7979/up
# {"status":"ok","database":true,"redis":true,"worker":true}
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

`bin/dev` runs the server and a webpack watcher; Sidekiq runs inside the server, as it does in the image. Set `PW_PORT` to move the server; plain `PORT` will not work, because foreman assigns its own to every process. `docker compose up` runs the published image rather than your working tree, so it is not a way to try a change.

```sh
bundle exec rspec
bundle exec rubocop
```

The specs render the layout, which needs a webpack manifest — run `./bin/shakapacker` once if you have not started `bin/dev`. CI runs the suite against both SQLite and PostgreSQL, so a migration has to be clean on both.

## License

The server is [AGPL-3.0](LICENSE), because it is a network service and AGPL is what stops a modified copy being run as a competing hosted service without the changes being published.
