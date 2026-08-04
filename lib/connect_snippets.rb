# frozen_string_literal: true

module ConnectSnippets
  # A shell variable, not <SPACE_UUID>: these are meant to be pasted into a console,
  # where an angle bracket is a redirect and would fail on the first line.
  PLACEHOLDER = '$SPACE_UUID'

  AGENT_SKILL = <<~MD.strip
    ---
    name: progress-watch
    description: >
      Report progress on long-running work so the user can watch it on their phone.
      Use when starting an operation with many steps or one that takes minutes or more.
    ---


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

    Create the whole tree before you start, and finish each step as it finishes rather
    than all of them at the end. A board that stays empty for the whole job and turns
    green at the finish is worth nothing to whoever is watching it.

    Keep adding steps as work appears. The tree is a live picture, not a plan fixed at
    the start — something you did not foresee gets its own step when you find it. The
    parent's bar dropping because it gained a step is honest.

    Say when a step begins even if it has nothing to count — send
    `{"current": 0, "end": 1}`, which reads as running. Without it the step sits at
    "waiting for data", which looks identical to a reporter that died.

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
        ports: ["7979:3000"]
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
      heading: 'Report progress from the command line',
      description: 'Track any command with the progresswatch CLI. Wrap a script in one line and watch it on your ' \
                   'phone, or report start, progress and finish by hand.',
      title: 'CLI',
      icon: 'terminal',
      steps: [
        { label: 'Install it.', body: 'npm install -g progresswatch' },
        { label: 'Point it at this server first. Saved to ~/.progresswatchrc, so this is a one-off.',
          body: 'progresswatch configure --server {{server}}', only: :self_hosted },
        { label: 'Create a space. It becomes the default, so nothing else needs configuring.',
          body: 'progresswatch space new "My work"', only: :without_space },
        { label: 'Point it at this space. Saved to ~/.progresswatchrc, so this is a one-off.',
          body: 'progresswatch space use {{space}}', only: :with_space },
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
      heading: 'Report progress with curl',
      description: 'Three curl calls are the whole integration: create a task, PUT its progress, PUT it done. No ' \
                   'SDK, no library, works from any shell or CI job.',
      title: 'curl',
      icon: 'globe',
      steps: [
        { label: 'Create a space, keep its uuid. Whoever has it can read and write here.',
          body: 'SPACE_UUID=$(curl -s -X POST {{server}}/spaces ' \
                "-H 'Content-Type: application/json' -d '{\"title\": \"My work\"}' | jq -r .uuid)",
          only: :without_space },
        { label: 'Create a task, keep its uuid.',
          body: 'TASK=$(curl -s -X POST {{server}}/spaces/{{space}}/tasks ' \
                "-H 'Content-Type: application/json' -d '{\"title\": \"Crawl docs\"}' | jq -r .uuid)" },
        { label: 'Report progress. Every write replaces the whole state — send all of it each time.',
          body: "curl -X PUT {{server}}/tasks/$TASK -H 'Content-Type: application/json' " \
                "-d '{\"current\": 1200, \"end\": 50000, \"values\": {\"pages\": 1200, \"errors\": 3}}'" },
        { label: 'Finish it. This is what sends the notification.',
          body: "curl -X PUT {{server}}/tasks/$TASK -H 'Content-Type: application/json' -d '{\"done\": true}'" },
        { label: 'The whole API as OpenAPI 3.1, if you would rather generate a client than write one. ' \
                 'Same document at /openapi.yml.',
          body: 'curl {{server}}/openapi.json' }
      ]
    },

    'agent' => {
      heading: 'Give an AI agent a progress skill',
      description: 'Drop a skill file into .claude/skills and an agent reports its own long-running work — one task ' \
                   'per job, one child task per step — so you can watch it from your phone.',
      title: 'Agent skill',
      icon: 'robot',
      steps: [
        { label: 'Save as .claude/skills/progress-watch/SKILL.md', body: AGENT_SKILL }
      ]
    },

    'mcp' => {
      heading: 'Connect an agent over MCP',
      description: 'Add Progress Watch as an MCP server and an agent gets four tools for creating tasks and ' \
                   'reporting progress, deciding on its own when tracking is worth it.',
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
      heading: 'Self-host Progress Watch with Docker',
      description: 'One container and a Redis. Progress never touches the database, so the volume stays tiny and ' \
                   'losing it costs you nothing but the space list.',
      title: 'Docker',
      icon: 'container',
      steps: [
        { label: 'Run your own server. Progress never touches the database, so the volume stays tiny and ' \
                 'losing it costs you nothing but the space list.', body: COMPOSE },
        { label: 'Start it.', body: 'docker compose up -d' },
        { label: 'Then point the CLI at it. This page is served from {{server}}.',
          body: 'export PROGRESSWATCH_SERVER="http://localhost:7979"' },
        { label: 'That is a working server. Notifications, Postgres and the rest are environment variables — ' \
                 'see Environment variables in the sidebar.' }
      ]
    }
  }.freeze

  module_function

  # A step may be marked for one kind of reader and is dropped for the others. Two axes:
  # where they are — progress.watch is the CLI's default server, so configuring one is
  # noise there and unskippable on somebody's own box — and whether they already have a
  # space, because a page reached without one has to show how to make it rather than
  # assume it.
  def call(section, base_url:, space_uuid: nil, hosted: ProgressWatch.multitenant?)
    here = [hosted ? :hosted : :self_hosted, space_uuid ? :with_space : :without_space]

    SECTIONS.fetch(section)[:steps]
            .select { |step| step[:only].nil? || here.include?(step[:only]) }
            .map { |step| step.except(:only).transform_values { |value| fill(value, base_url, space_uuid) } }
  end

  def fill(value, base_url, space_uuid)
    value&.gsub('{{server}}', base_url)&.gsub('{{space}}', space_uuid || PLACEHOLDER)
  end
end
