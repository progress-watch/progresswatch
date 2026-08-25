# frozen_string_literal: true

module Tasks
  module SerializeForApi
    FINISHED_WITHOUT_STATE = {
      'current' => nil,
      'end' => nil,
      'ratio' => nil,
      'values' => {},
      'updated_at' => nil,
      'aggregated' => false
    }.freeze

    module_function

    def call(task)
      children = task.children.order(:created_at).to_a
      states = TaskStates.read_many([task.uuid] + children.map(&:uuid))

      render(task, children, states)
    end

    def render(task, children, states)
      {
        'uuid' => task.uuid,
        'space_uuid' => task.space_uuid,
        'parent_uuid' => task.parent_uuid,
        'title' => task.title,
        'source' => task.source,
        'created_at' => task.created_at.utc.iso8601(6),
        'finished_at' => task.finished_at&.utc&.iso8601(6),
        'duration' => task.duration,
        'progress' => progress(task, children, states),
        'children' => children.map { |child| render(child, [], states) }
      }
    end

    def progress(task, children, states)
      return leaf(task, states[task.uuid]) if children.empty?

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

    def leaf(task, state)
      return state&.as_json unless task.finished_at?

      (state&.as_json || FINISHED_WITHOUT_STATE).merge('ratio' => 1.0)
    end

    def child_ratio(child, state)
      return 1.0 if child.finished_at?

      state&.ratio || 0.0
    end
  end
end
