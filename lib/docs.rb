# frozen_string_literal: true

module Docs
  DOCUMENTS = [
    {
      id: 1,
      slug: 'self-hosting',
      title: 'Self-hosting',
      icon: 'server',
      heading: 'Running your own Progress Watch',
      meta_description: 'How to run and configure your own Progress Watch server.',
      date: '2026-08-07'
    },
    {
      id: 2,
      slug: 'notifications',
      title: 'Notifications',
      icon: 'bell',
      heading: 'Getting notified when something finishes',
      meta_description: 'How Progress Watch notifies you when work finishes, and how to turn it on.',
      date: '2026-08-07'
    },
    {
      id: 3,
      slug: 'environment-variables',
      title: 'Environment variables',
      icon: 'gear',
      heading: 'Configuring Progress Watch via environment variables',
      meta_description: 'Every environment variable a self-hosted Progress Watch reads.',
      date: '2026-08-04'
    }
  ].freeze
end
