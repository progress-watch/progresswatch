# frozen_string_literal: true

module Tasks
  # The only place that decides what a task looks like on the wire. The response
  # shape and the aggregation rules are documented in README.md.
  module SerializeForApi
    module_function

    def call(task)
      children = task.children.order(:created_at).to_a
      states = TaskStates.read_many([task.uuid] + children.map(&:uuid))

      render(task, children, states)
    end

    # Children are passed in empty because nesting is one level: this never recurses
    # more than once.
    def render(task, children, states)
      {
        'uuid' => task.uuid,
        'space_uuid' => task.space_uuid,
        'parent_uuid' => task.parent_uuid,
        'title' => task.title,
        'source' => task.source,
        'created_at' => task.created_at.utc.iso8601,
        'finished_at' => task.finished_at&.utc&.iso8601,
        'duration' => task.duration,
        'progress' => progress(task, children, states),
        'children' => children.map { |child| render(child, [], states) }
      }
    end

    def progress(task, children, states)
      return states[task.uuid]&.as_json if children.empty?

      own = states[task.uuid]
      ratios = children.map { |child| child_ratio(child, states[child.uuid]) }
      updates = children.map { |child| states[child.uuid]&.updated_at } << own&.updated_at

      {
        'current' => children.count(&:finished_at?),
        'end' => children.size,
        'ratio' => ratios.sum / ratios.size,
        'values' => own&.values || {},
        'updated_at' => updates.compact.max,
        'aggregated' => true
      }
    end

    # finished_at? wins over the stored state because Redis may have expired since,
    # while finished_at is on disk.
    def child_ratio(child, state)
      return 1.0 if child.finished_at?

      state&.ratio || 0.0
    end
  end
end
