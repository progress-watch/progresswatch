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

- [CLI](https://github.com/progress-watch/progresswatch-cli) for shells and CI jobs
- MCP server and an agent skill for AI agents
- One HTTP request from anything else, no SDK needed
- Counts, not just percentages: `1200 / 50000 pages`
- Steps, one level deep
- Live dashboard in the browser
- Web Push when something finishes, with nothing to register with Apple or Google
- No accounts: a space UUID is the credential
- Progress stays out of the database, so it never grows
- SQLite or PostgreSQL

## Deploy

|Render|DigitalOcean|Railway|
|:--:|:--:|:--:|
| [<img alt="Deploy to Render" src="https://render.com/images/deploy-to-render-button.svg" height="40">](https://render.com/deploy?repo=https://github.com/progress-watch/progresswatch) | [<img alt="Deploy to DigitalOcean" src="https://www.deploytodo.com/do-btn-blue.svg" height="40">](https://cloud.digitalocean.com/apps/new?repo=https://github.com/progress-watch/progresswatch/tree/master) | [<img alt="Deploy on Railway" src="https://railway.com/button.svg" height="40">](https://railway.com/deploy/progress-watch?referralCode=P9RGBN&utm_medium=integration&utm_source=template&utm_campaign=generic) |

#### Docker

```sh
docker run --name progresswatch -p 7979:3000 -v progresswatch:/data progresswatch/progresswatch
```

Then open `http://localhost:7979`. It uses SQLite by default; set `DATABASE_URL` to use PostgreSQL.

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

Everything is configured with [environment variables](https://progress.watch/docs/environment-variables).

## Reporting into it

```sh
npm install -g progresswatch
progresswatch space new "My work"

TASK=$(progresswatch new "Crawl docs")
progresswatch update $TASK --current 1200 --end 50000 --values pages=1200
progresswatch done $TASK
```

Or wrap a command you cannot change; that reports a start and a finish, not counts:

```sh
progresswatch run "python train.py"
```

## Documentation

- [Get started](https://progress.watch/docs)
- [CLI](https://progress.watch/docs/cli) · [Agent skill](https://progress.watch/docs/agent) · [MCP](https://progress.watch/docs/mcp) · [curl](https://progress.watch/docs/curl)
- [API Reference](https://progress.watch/docs/api)
- [Self-hosting](https://progress.watch/docs/self-hosting)
- [Notifications](https://progress.watch/docs/notifications)
- [Environment variables](https://progress.watch/docs/environment-variables)

## Development

Ruby 4.0.5 (see `.tool-versions`), Node 22, and a local Redis.

```sh
bundle install
npm install
bin/rails db:prepare
bin/dev
```

Set `PW_PORT` to move the server, since foreman overrides `PORT`. `docker compose up` runs the published image, not your checkout.

```sh
bundle exec rspec
bundle exec rubocop
```

Run `./bin/shakapacker` once before the specs if `bin/dev` has not built the assets yet. Migrations have to run on both SQLite and PostgreSQL, and CI checks both.

## License

Distributed under the [AGPL-3.0](LICENSE) license.
