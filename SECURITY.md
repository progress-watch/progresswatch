# Security

## Reporting a vulnerability

Use [private vulnerability reporting](https://github.com/progress-watch/progresswatch/security/advisories/new).
It goes to the maintainers and stays private until there is a fix. Please do not open a
public issue for anything that could be exploited against a running instance.

You can expect a first reply within a few days, and to be credited in the advisory unless
you would rather not be.

## Supported versions

The latest `1.x` release. There is one maintained line, and fixes land in a new patch
release rather than being backported.

## What is worth reporting

A space UUID is the only credential in this system: whoever has it can read a space and
report into it. So anything that leaks one, or lets a request reach a space without one,
is a real finding — an endpoint that echoes a UUID into a log or an error page, a way to
enumerate spaces, a cache header that lets a shared browser expose one.

The API is deliberately unauthenticated beyond that UUID, and there are no accounts, no
passwords and no sessions. That is a design decision rather than an oversight, and reports
that amount to "there is no login" will be closed with a link to this paragraph.
