# frozen_string_literal: true

module ConnectSnippets
  # A shell variable, not <SPACE_UUID>: these are meant to be pasted into a console,
  # where an angle bracket is a redirect and would fail on the first line.
  PLACEHOLDER = '$SPACE_UUID'

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

  COMPOSE = Rails.root.join('docker-compose.yml').read.strip

  SECTIONS = {
    'cli' => {
      heading: 'Report progress from the command line',
      description: 'Report progress from a script or a CI job with the progresswatch CLI: create a task, update ' \
                   'it as the work moves, close it. Or wrap a command you cannot change in one line.',
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
        { label: 'Create a task where the work starts, and keep the uuid.',
          body: 'TASK=$(progresswatch new "Crawl docs")' },
        { label: 'Report as it moves. This is the call that goes in your loop, and the only one that knows ' \
                 'the numbers.',
          body: 'progresswatch update $TASK --current 1200 --end 50000 --values pages=1200' },
        { label: 'Close it. This is what sends the notification, so call it for a failure too.',
          body: 'progresswatch done $TASK' },
        { label: 'Or wrap a process that is not yours to change. It reports start and finish rather than ' \
                 'counts, and exits with the command status.',
          body: 'progresswatch run "python train.py"' },
        { label: 'In CI there is no config file to write, so pass it in the environment instead.',
          body: 'export PROGRESSWATCH_SERVER="{{server}}" PROGRESSWATCH_SPACE="{{space}}"' }
      ]
    },

    'agent' => {
      heading: 'Give an AI agent a progress skill',
      description: 'One command installs a skill your coding agent reads, and it reports its own long-running ' \
                   'work — one task per job, one child task per step — so you can watch it from anywhere.',
      title: 'Agent skill',
      icon: 'robot',
      intro: 'The skill drives the CLI, so the agent needs no server or uuid of its own — it uses whatever this ' \
             'machine is already configured for.',
      steps: [
        { label: 'Install the CLI. The skill is a set of instructions for driving it.',
          body: 'npm install -g progresswatch' },
        { label: 'Point it at this server. Saved to ~/.progresswatchrc, so this is a one-off.',
          body: 'progresswatch configure --server {{server}}', only: :self_hosted },
        { label: 'Create a space for the agent to report into.',
          body: 'progresswatch space new "Agent work"', only: :without_space },
        { label: 'Point it at this space. Use --local to bind it to one project instead.',
          body: 'progresswatch space use {{space}}', only: :with_space },
        { label: 'Install the skill. It knows 75+ agents and asks which to install for.',
          body: 'npx skills add progress-watch/progresswatch-cli' },
        { label: 'That is all — the agent decides on its own when work is worth tracking, creates a task for the ' \
                 'job and a child task per step, and closes each one as it finishes. If you would rather not run ' \
                 'somebody else\'s installer, the same file is skills/progresswatch-cli/SKILL.md in that ' \
                 'repository, and it goes in .claude/skills/.' }
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

    'curl' => {
      heading: 'Try the API with curl',
      description: 'See the whole API in four requests before you write it into anything: create a space, create a ' \
                   'task, report progress, finish it. Nothing to install.',
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
        { label: 'That is the whole surface, and it is what the CLI and the MCP tools call. For something you ' \
                 'run every day the CLI is one line instead of four; to build on it, the API reference and ' \
                 'OpenAPI 3.1 are at /openapi.json.' }
      ]
    },

    'docker' => {
      heading: 'Self-host Progress Watch with Docker',
      description: 'One container and a Redis. Progress never touches the database, so the volume stays tiny and ' \
                   'losing it costs you nothing but the space list.',
      title: 'Docker',
      icon: 'container',
      intro: 'Your own server, on your own box. Nothing here talks to progress.watch.',
      steps: [
        { label: 'Save this as docker-compose.yml. It runs the published image, so there is nothing to clone ' \
                 'and nothing to build — and it is yours to edit from here on.', body: COMPOSE },
        { label: 'Generate a secret and paste it over the placeholder, in both services.',
          body: 'openssl rand -hex 64' },
        { label: 'Start it. The app, a worker for notifications, a Redis, and a SQLite file on a volume.',
          body: 'docker compose up -d' },
        { label: 'Then point the CLI at it. This page is served from {{server}}.',
          body: 'export PROGRESSWATCH_SERVER="http://localhost:7979"' },
        { label: 'That is a working server. Notifications, Postgres, the one thing worth putting on a cron and ' \
                 'the one-click deploy are all in Self-hosting in the sidebar.' }
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
