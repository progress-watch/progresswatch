# frozen_string_literal: true

# Everything behind the Connect menu, as data. One SECTIONS entry per section: its
# title, its icon partial, and the steps it renders.
#
# Steps rather than one blob per section, because the thing a reader does with this
# page is copy one command at a time. A body with no newline renders as a single-line
# field, a longer one as a block, and a step with no body at all is prose.
#
# `{{server}}` and `{{space}}` are filled in by `call`. Substitution rather than
# interpolation is what lets this be data instead of a method per section, and `gsub`
# rather than `format` so a stray `%` in a snippet stays a stray `%`.
#
# The long bodies are named above SECTIONS rather than inlined: a heredoc opened inside
# a hash literal has to be indented to wherever the hash sits, and rubocop's own
# formatting of that is unreadable.
module ConnectSnippets
  PLACEHOLDER = '<SPACE_UUID>'

  AGENT_SKILL = <<~MD.strip
    ---
    name: progress-watch
    description: >
      Report progress on long-running work so the user can watch it on their phone.
      Use when starting an operation with many steps or one that takes minutes or more.
    ---

    # Reporting progress

    Space: {{space}}
    Server: {{server}}

    When you begin a long operation, create a task:

        curl -s -X POST {{server}}/spaces/{{space}}/tasks \\
          -H 'Content-Type: application/json' \\
          -d '{"title": "<what you are doing>", "source": "claude-code"}'

    Keep the returned uuid. Report every meaningful step:

        curl -X PUT {{server}}/tasks/<uuid> \\
          -H 'Content-Type: application/json' \\
          -d '{"current": 3, "end": 10, "values": {"log": "<last line>"}}'

    When you decompose work into steps, create one child task per step by passing
    `parent_uuid`. Nesting is one level only — a child cannot have children. The
    parent's bar averages its children, so never update the parent yourself.

    Every write replaces the whole state. Send the complete state each time; anything
    you leave out is cleared, not kept.

    Mark the task done when it finishes, which is what sends the notification:

        curl -X PUT {{server}}/tasks/<uuid> \\
          -H 'Content-Type: application/json' -d '{"done": true}'
  MD

  MCP_IN_URL = <<~JSON.strip
    {
      "mcpServers": {
        "progress-watch": {
          "type": "http",
          "url": "{{server}}/mcp/{{space}}"
        }
      }
    }
  JSON

  MCP_IN_HEADER = <<~JSON.strip
    {
      "mcpServers": {
        "progress-watch": {
          "type": "http",
          "url": "{{server}}/mcp",
          "headers": { "X-Space-Uuid": "{{space}}" }
        }
      }
    }
  JSON

  COMPOSE = <<~YML.strip
    services:
      app:
        image: progresswatch/progresswatch:latest
        ports: ["3000:3000"]
        volumes: ["storage:/rails/storage"]
        environment:
          DATABASE_URL: sqlite3:storage/production.sqlite3
          REDIS_URL: redis://redis:6379
          SECRET_KEY_BASE: change-me
        depends_on: [redis]

      redis:
        image: redis:8-alpine
        command: redis-server --save "" --appendonly no

    volumes:
      storage:
  YML

  SECTIONS = {
    'cli' => {
      title: 'CLI',
      icon: 'terminal',
      steps: [
        { label: 'Install it.', body: 'npm install -g progresswatch' },
        { label: 'Point it at this space. Saved to ~/.progresswatchrc, so this is a one-off.',
          body: 'progresswatch space use {{space}} --server {{server}}' },
        { label: 'Wrap anything. It reports start and finish, and pushes when it is done.',
          body: 'progresswatch run "python train.py"' },
        { label: 'Or report by hand.', body: 'TASK=$(progresswatch new "Crawl docs")' },
        { body: 'progresswatch update $TASK --current 1200 --end 50000 --values pages=1200' },
        { body: 'progresswatch done $TASK' },
        { label: 'In CI there is no config file to write, so pass it in the environment instead.',
          body: 'export PROGRESSWATCH_SERVER="{{server}}" PROGRESSWATCH_SPACE="{{space}}"' }
      ]
    },

    'curl' => {
      title: 'curl',
      icon: 'globe',
      steps: [
        { label: 'Create a task, keep its uuid.',
          body: 'TASK=$(curl -s -X POST {{server}}/spaces/{{space}}/tasks ' \
                "-H 'Content-Type: application/json' -d '{\"title\": \"Crawl docs\"}' | jq -r .uuid)" },
        { label: 'Report progress. Every write replaces the whole state — send all of it each time.',
          body: "curl -X PUT {{server}}/tasks/$TASK -H 'Content-Type: application/json' " \
                "-d '{\"current\": 1200, \"end\": 50000, \"values\": {\"pages\": 1200, \"errors\": 3}}'" },
        { label: 'Finish it. This is what sends the notification.',
          body: "curl -X PUT {{server}}/tasks/$TASK -H 'Content-Type: application/json' -d '{\"done\": true}'" }
      ]
    },

    'agent' => {
      title: 'Agent skill',
      icon: 'robot',
      steps: [
        { label: 'Save as .claude/skills/progress-watch/SKILL.md', body: AGENT_SKILL }
      ]
    },

    'mcp' => {
      title: 'MCP',
      icon: 'plug',
      steps: [
        { label: 'Add the server.', body: 'claude mcp add --transport http progress-watch {{server}}/mcp/{{space}}' },
        { label: 'Or write it into .mcp.json yourself.', body: MCP_IN_URL },
        { label: 'The space uuid sits in the URL, so any client that takes only a URL works. To keep it out ' \
                 'of the path, send it as a header instead.', body: MCP_IN_HEADER },
        { label: 'Four tools: create_space, create_task, update_task, complete_task. The agent ' \
                 'decides on its own when to create a task and how often to report. One connected without a ' \
                 'space can call create_space and hand you back the URL, so it is never stuck with nowhere ' \
                 'to report.' }
      ]
    },

    'docker' => {
      title: 'Docker',
      icon: 'container',
      steps: [
        { label: 'Run your own server. Progress never touches the database, so the volume stays tiny and ' \
                 'losing it costs you nothing but the space list.', body: COMPOSE },
        { label: 'Start it.', body: 'docker compose up -d' },
        { label: 'Then point the CLI at it. This page is served from {{server}}.',
          body: 'export PROGRESSWATCH_SERVER="http://localhost:3000"' }
      ]
    }
  }.freeze

  module_function

  def call(section, base_url:, space_uuid: PLACEHOLDER)
    SECTIONS.fetch(section)[:steps].map do |step|
      step.transform_values { |value| fill(value, base_url, space_uuid) }
    end
  end

  def fill(value, base_url, space_uuid)
    value&.gsub('{{server}}', base_url)&.gsub('{{space}}', space_uuid)
  end
end
