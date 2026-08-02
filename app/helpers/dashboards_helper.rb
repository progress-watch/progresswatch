# frozen_string_literal: true

# View formatting only. Anything that decides what a task *is* belongs in
# lib/tasks/serialize_for_api.rb, not here.
module DashboardsHelper
  def format_duration(seconds)
    return "#{seconds}s" if seconds < 60
    return "#{seconds / 60}m #{seconds % 60}s" if seconds < 3600

    "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
  end

  # Active first, newest first within each group. Ordering is the client's business,
  # not the API's — the serializer keeps creation order so every client gets the same
  # thing to sort.
  #
  # reverse rather than sort_by(created_at): Ruby's sort_by is not stable, so two tasks
  # created in the same second would swap places on every poll. Reversing the order the
  # serializer already guarantees cannot.
  def display_order(tasks)
    tasks.partition { |task| task['finished_at'].blank? }.flat_map(&:reverse)
  end

  # An aggregated parent counts finished children; a leaf shows its own numbers.
  def task_counts(progress)
    current = progress['current']
    return nil if current.nil?

    ending = progress['end']
    return current.to_s if ending.nil?

    progress['aggregated'] ? "#{current}/#{ending} done" : "#{current}/#{ending}"
  end
end
