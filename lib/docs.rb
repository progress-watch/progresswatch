# frozen_string_literal: true

module Docs
  DOCUMENTS = [
    {
      id: 1,
      slug: 'http-api',
      title: 'HTTP API',
      icon: 'code',
      heading: 'The HTTP API',
      meta_description: 'Every endpoint Progress Watch has, with curl examples: create a space, create a task, ' \
                        'report progress, finish it. Plus the semantics worth knowing before you build on it.',
      date: '2026-08-07'
    },
    {
      id: 2,
      slug: 'self-hosting',
      title: 'Self-hosting',
      icon: 'server',
      heading: 'Running your own Progress Watch',
      meta_description: 'Self-host Progress Watch with Docker Compose, or deploy it to Render, DigitalOcean or ' \
                        'Heroku in one click. What each process does, what the volume holds, and what to run on a ' \
                        'schedule.',
      date: '2026-08-07'
    },
    {
      id: 3,
      slug: 'notifications',
      title: 'Notifications',
      icon: 'bell',
      heading: 'Getting notified when something finishes',
      meta_description: 'Progress Watch notifies through Web Push, straight from your server to the browser. ' \
                        'Generate a VAPID pair, install the site on a phone, and know what each party learns.',
      date: '2026-08-07'
    },
    {
      id: 4,
      slug: 'environment-variables',
      title: 'Environment variables',
      icon: 'gear',
      heading: 'Configuring Progress Watch via environment variables',
      meta_description: 'Every environment variable a self-hosted Progress Watch reads: database, Redis, Web Push ' \
                        'keys, process sizing, and what each one defaults to.',
      date: '2026-08-04'
    }
  ].freeze
end
