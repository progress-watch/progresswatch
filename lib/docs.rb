# frozen_string_literal: true

module Docs
  DOCUMENTS = [
    {
      id: 1,
      slug: 'self-hosting',
      title: 'self_hosting',
      icon: 'server',
      heading: 'running_your_own_progress_watch',
      meta_description: 'how_to_run_and_configure_your_own_progress_watch_server'
    },
    {
      id: 2,
      slug: 'notifications',
      title: 'notifications',
      icon: 'bell',
      heading: 'getting_notified_when_something_finishes',
      meta_description: 'how_progress_watch_notifies_you_when_work_finishes_and_how_to_turn_it_on'
    },
    {
      id: 3,
      slug: 'environment-variables',
      title: 'environment_variables',
      icon: 'gear',
      heading: 'configuring_progress_watch_via_environment_variables',
      meta_description: 'every_environment_variable_a_self_hosted_progress_watch_reads'
    }
  ].freeze
end
