# frozen_string_literal: true

module Tasks
  # Everything the dashboard decides about a task before rendering it: what order the
  # rows come in, and the three strings that are not simply a field.
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
