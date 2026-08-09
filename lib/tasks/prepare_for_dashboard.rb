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

    # reverse, not sort_by(created_at): sort_by is not stable, so tasks created in the
    # same second would swap places on every poll.
    def order(tasks)
      tasks.partition { |task| task['finished_at'].blank? }.flat_map(&:reverse)
    end

    def finished_label(task)
      return nil if task['finished_at'].blank?
      return 'finished' if task['duration'].blank?

      "finished in #{duration(task['duration'])}"
    end

    # How long it took and when it happened are two different questions, and a board with
    # a week of history answers only the first without this.
    def finished_ago(task)
      return nil if task['finished_at'].blank?

      ago((Time.current - Time.zone.parse(task['finished_at'])).round)
    end

    # The tooltip, for when the coarse answer is not enough. UTC spelled out rather than
    # localised: the server does not know the reader's zone, and guessing wrong about a
    # timestamp is worse than making them do the arithmetic.
    def finished_on(task)
      return nil if task['finished_at'].blank?

      Time.zone.parse(task['finished_at']).strftime('%-d %b %Y, %H:%M UTC')
    end

    # Coarser than `duration` on purpose: "when" is answered by an order of magnitude, and
    # duration would say "72h" for something two days old.
    def ago(seconds)
      return 'just now' if seconds < 60
      return "#{seconds / 60}m ago" if seconds < 3600
      return "#{seconds / 3600}h ago" if seconds < 86_400

      "#{seconds / 86_400}d ago"
    end

    def idle_label(task)
      return nil if task['finished_at'].present?

      reported = task['progress'] && task['progress']['updated_at']
      seconds = (Time.current - Time.zone.parse(reported || task['created_at'])).round

      return "waiting #{duration(seconds)}" if reported.nil?
      return nil if seconds < IDLE_AFTER

      "idle #{duration(seconds)}"
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

      progress['aggregated'] ? "#{current}/#{ending} done" : "#{current}/#{ending}"
    end
  end
end
