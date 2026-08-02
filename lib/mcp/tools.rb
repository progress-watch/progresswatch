# frozen_string_literal: true

module Mcp
  # Keep `description` last in every definition: a heredoc opened mid-hash breaks
  # syntax highlighting for everything after it.
  module Tools
    MissingSpace = Class.new(StandardError)

    DEFINITIONS = [
      {
        'name' => 'create_space',
        'title' => 'Create a space to report into',
        'inputSchema' => {
          'type' => 'object',
          'properties' => {
            'title' => {
              'type' => 'string',
              'description' => 'What this collection of tasks is for, e.g. "Nightly builds".'
            },
            'icon' => {
              'type' => 'string',
              'description' => 'One character shown beside the name. An emoji reads best, e.g. "🌙".'
            }
          },
          # Required although the HTTP API allows an untitled space: this name is all
          # the user ever sees of it.
          'required' => ['title']
        },
        'description' => <<~TEXT
          Create a space — the container tasks live in, and what the user opens to watch
          them.

          Only call this when no space is configured for this connection and creating a
          task failed for that reason. If a space is already configured, use it: making a
          second one splits the user's tasks across two screens they have to add
          separately.

          Returns the space uuid and the URL to watch it. Give the user that URL — until
          they open it, nothing you report is visible to them, and the uuid is the only
          way back to it.
        TEXT
      },
      {
        'name' => 'create_task',
        'title' => 'Create a progress task',
        'inputSchema' => {
          'type' => 'object',
          'properties' => {
            'title' => { 'type' => 'string', 'description' => 'What this task is doing, in a few words.' },
            'parent_uuid' => {
              'type' => 'string',
              'description' => 'Make this a step of an existing task. One level only.'
            },
            'space_uuid' => {
              'type' => 'string',
              'description' => 'Only needed to override the space configured for this connection.'
            },
            'source' => {
              'type' => 'string',
              'description' => 'What is reporting, e.g. the agent or tool name.'
            }
          },
          'required' => ['title']
        },
        'description' => <<~TEXT
          Create a task the user can watch on their phone.

          Call this when you are starting a long-running operation the user might want to
          track — anything with many steps, or that will take more than a minute. Returns
          a task uuid to report against.

          If you decompose work into steps, create one child task per step by passing
          parent_uuid. Nesting is one level only: a child cannot have children. A parent's
          progress is averaged from its children automatically, so never report progress
          on a parent yourself.

          Create the whole tree before starting, then report each step as it happens and
          complete it when it is actually done — not all of them at the end. A board that
          stays empty for the whole job and turns green at the finish is worth nothing to
          whoever is watching it.
        TEXT
      },
      {
        'name' => 'update_task',
        'title' => 'Report progress',
        'inputSchema' => {
          'type' => 'object',
          'properties' => {
            'task_uuid' => { 'type' => 'string', 'description' => 'The uuid returned by create_task.' },
            'current' => { 'type' => 'number', 'description' => 'How much is done so far.' },
            'end' => { 'type' => 'number', 'description' => 'How much there is in total.' },
            'values' => {
              'type' => 'object',
              'description' => 'Flat object of extra numbers or strings, e.g. {"errors": 3, "log": "retrying /foo"}.'
            }
          },
          'required' => ['task_uuid']
        },
        'description' => <<~TEXT
          Report progress on a task. Call periodically — every meaningful step, not every
          loop iteration.

          Call it once when the work actually begins, too. A task that has been created but
          never reported reads as "waiting for data", which nobody can tell apart from a
          reporter that died before its first write. If the step has nothing to count, send
          current 0 and end 1: that reads as running, and it is honest.

          `current` and `end` are raw counts, not a percentage: the user sees
          "1200 of 50000 pages", which tells them something "2.4%" does not. `end` may
          change as you learn more; send the new number and the bar recalculates.

          Every call replaces the whole state. Send everything each time — anything you
          leave out is cleared, not kept. Put a one-line status in values.log; it holds
          the last line only, not a history.

          A task uuid is all this needs — it already knows which space it belongs to.
        TEXT
      },
      {
        'name' => 'complete_task',
        'title' => 'Finish a task',
        'inputSchema' => {
          'type' => 'object',
          'properties' => {
            'task_uuid' => { 'type' => 'string', 'description' => 'The uuid returned by create_task.' },
            'values' => {
              'type' => 'object',
              'description' => 'Final numbers or a closing log line, e.g. {"status": "failed", "log": "exit 1"}.'
            }
          },
          'required' => ['task_uuid']
        },
        'description' => <<~TEXT
          Mark a task finished. This is what sends the user's push notification, so call
          it when the work is actually done — including when it failed, with the failure
          recorded in values.
        TEXT
      }
    ].freeze

    module_function

    def call(name, arguments, space_uuid:, base_url:)
      case name
      when 'create_space' then create_space(arguments, base_url)
      when 'create_task' then create_task(arguments, space_uuid)
      when 'update_task' then update_task(arguments)
      when 'complete_task' then complete_task(arguments)
      end
    end

    def exists?(name)
      DEFINITIONS.any? { |tool| tool['name'] == name }
    end

    def create_space(arguments, base_url)
      space = Spaces::Create.call(title: arguments['title'].presence, icon: arguments['icon'])

      text(<<~TEXT)
        Space created: #{space.uuid}

        Tell the user to open #{base_url}/s/#{space.uuid} to watch it. Pass this uuid as
        space_uuid when creating tasks, or configure it on the MCP connection so you do
        not have to.
      TEXT
    end

    def create_task(arguments, space_uuid)
      uuid = arguments['space_uuid'].presence || space_uuid
      raise MissingSpace, 'no space configured for this MCP connection; call create_space first' if uuid.blank?

      task = Tasks::Create.call(
        space: Space.find(uuid),
        title: arguments['title'],
        source: arguments['source'].presence || 'mcp',
        parent_uuid: arguments['parent_uuid'].presence
      )

      text("Task created. Report against uuid #{task.uuid}.")
    end

    def update_task(arguments)
      task = Task.find(arguments['task_uuid'])

      Tasks::Report.call(task, current: arguments['current'], end_value: arguments['end'],
                               values: arguments['values'])

      text('Progress reported.')
    end

    def complete_task(arguments)
      task = Task.find(arguments['task_uuid'])

      Tasks::Report.call(task, current: 1, end_value: 1, values: arguments['values'], done: true)

      text('Task marked done. The user has been notified.')
    end

    def text(message)
      { 'content' => [{ 'type' => 'text', 'text' => message }] }
    end

    # A tool failure is a result the agent reads and adjusts to, not a JSON-RPC error.
    def error(message)
      { 'content' => [{ 'type' => 'text', 'text' => message }], 'isError' => true }
    end
  end
end
