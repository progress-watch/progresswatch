# frozen_string_literal: true

module Spaces
  module SerializeForApi
    module_function

    # One query and one MGET whatever the task count: this is polled every 2-3 seconds.
    def call(space)
      tasks = space.tasks.order(:created_at).to_a
      states = TaskStates.read_many(tasks.map(&:uuid))
      children_by_parent = tasks.group_by(&:parent_uuid)

      {
        'uuid' => space.uuid,
        'title' => space.title,
        'icon' => space.icon,
        'tasks' => tasks.filter_map do |task|
          next unless task.parent_uuid.nil?

          Tasks::SerializeForApi.render(task, children_by_parent[task.uuid] || [], states)
        end
      }
    end
  end
end
