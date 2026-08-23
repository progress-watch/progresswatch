# frozen_string_literal: true

module Tasks
  # Everything the dashboard decides about a task before rendering it: what order the
  # rows come in, and the strings that are not simply a field.
  #
  # SerializeForApi keeps creation order and raw numbers for every client; what to do
  # with them is the web UI's business, and it happens once here rather than per row in
  # a recursive partial.
  module PrepareForDashboard
    IDLE_AFTER = 10.minutes

    module_function

    def call(tasks)
      order(tasks).each do |task|
        task['children'] = call(task['children'] || [])
        task['finished_label'] = finished_label(task)
        task['finished_ago'] = finished_ago(task)
        task['finished_on'] = finished_on(task)
        task['idle_label'] = idle_label(task)
        task['counts_label'] = counts_label(task['progress'])
      end
    end

    # By created_at and never finished_at, or the buckets interleave. Months and not days
    # because the server does not know the reader's timezone and must not learn it.
    def sections(tasks)
      call(tasks)
        .group_by { |task| I18n.l(Time.zone.parse(task['created_at']), format: '%B %Y') }
        .map { |heading, group| { 'heading' => heading, 'tasks' => group } }
    end

    # reverse, not sort_by(created_at): sort_by is not stable, so tasks created in the
    # same second would swap places on every poll.
    def order(tasks)
      tasks.partition { |task| task['finished_at'].blank? }.flat_map(&:reverse)
    end

    def finished_label(task)
      return nil if task['finished_at'].blank?
      return I18n.t('finished') if task['duration'].blank?

      I18n.t('finished_in_duration', duration: duration(task['duration']))
    end

    # How long it took and when it happened are two different questions, and a board with
    # a week of history answers only the first without this.
    def finished_ago(task)
      return nil if task['finished_at'].blank?

      ago((Time.current - Time.zone.parse(task['finished_at'])).round)
    end

    # The month name follows the locale, the zone never does: the server does not know
    # the reader's, and a timestamp quietly three hours out is worse than arithmetic.
    def finished_on(task)
      return nil if task['finished_at'].blank?

      I18n.l(Time.zone.parse(task['finished_at']), format: '%-d %b %Y, %H:%M UTC')
    end

    # Coarser than `duration` on purpose: "when" is answered by an order of magnitude, and
    # duration would say "72h" for something two days old.
    def ago(seconds)
      return I18n.t('just_now') if seconds < 60
      return I18n.t('count_m_ago', count: seconds / 60) if seconds < 3600
      return I18n.t('count_h_ago', count: seconds / 3600) if seconds < 86_400

      I18n.t('count_d_ago', count: seconds / 86_400)
    end

    def idle_label(task)
      return nil if task['finished_at'].present?

      reported = task['progress'] && task['progress']['updated_at']
      seconds = (Time.current - Time.zone.parse(reported || task['created_at'])).round

      return I18n.t('waiting_duration', duration: duration(seconds)) if reported.nil?
      return nil if seconds < IDLE_AFTER

      I18n.t('idle_duration', duration: duration(seconds))
    end

    def duration(seconds)
      return "#{seconds}s" if seconds < 60
      return "#{seconds / 60}m #{seconds % 60}s".delete_suffix(' 0s') if seconds < 3600

      "#{seconds / 3600}h #{(seconds % 3600) / 60}m".delete_suffix(' 0m')
    end

    # An aggregated parent counts finished children; a leaf shows its own numbers.
    def counts_label(progress)
      current = progress && progress['current']
      return nil if current.nil?

      ending = progress['end']
      return current.to_s if ending.nil?

      progress['aggregated'] ? I18n.t('current_total_done', current:, total: ending) : "#{current}/#{ending}"
    end
  end
end
