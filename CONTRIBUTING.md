# Contributing

Thanks for looking. This is a small project and the fastest way to help is to tell us what
happened when you ran it.

## Where things go

- **A bug** — [an issue](https://github.com/progress-watch/progresswatch/issues/new/choose).
- **An idea, or something you wish it did** — [Discussions → Ideas](https://github.com/progress-watch/progresswatch/discussions/categories/ideas).
  This is the part we most want to hear about right now: the shape of the tool is not
  settled, and what you are actually tracking decides it.
- **A question** — [Discussions → Q&A](https://github.com/progress-watch/progresswatch/discussions/categories/q-a).
- **Something you built with it** — [Discussions → Show and tell](https://github.com/progress-watch/progresswatch/discussions/categories/show-and-tell).

For anything larger than a fix, open a discussion before writing the code. It is a short
conversation that saves an afternoon, and some things are left out on purpose — the README
and [the docs](https://progress.watch/docs) say which.

## Running it

Setup, the dev server and the test commands are in the [Development](README.md#development)
section of the README. Two things that catch people:

- **`docker compose up` runs the published image, not your working tree.** It is there so
  a self-hoster can copy one file and never clone. Use `bin/dev` to try a change.
- **The suite runs against SQLite and PostgreSQL, and CI runs both.** A migration or a
  query that only works on one is not done. `DATABASE_URL` picks the adapter.

Before opening a pull request:

```sh
bundle exec rspec
bundle exec rubocop
```

## The client

The CLI, the MCP server and the agent skill live in
[progresswatch-cli](https://github.com/progress-watch/progresswatch-cli) and are released
separately. Issues about `progresswatch` the command belong there; discussions about the
product belong here, so there is one place to read.
