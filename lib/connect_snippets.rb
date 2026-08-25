# frozen_string_literal: true

module ConnectSnippets
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
      heading: 'report_progress_from_the_command_line',
      description: 'report_progress_from_a_shell_a_script_or_a_ci_job_with_the_cli',
      title: 'cli',
      icon: 'terminal',
      steps: [
        {
          label: 'install_it',
          body: 'npm install -g progresswatch'
        },
        {
          label: 'point_it_at_this_server_first_saved_to_progresswatchrc',
          body: 'progresswatch configure --server {{server}}',
          only: :self_hosted
        },
        {
          label: 'create_a_space_it_becomes_the_default',
          body: 'progresswatch space new "My work"',
          only: :without_space
        },
        {
          label: 'point_it_at_this_space_saved_to_progresswatchrc',
          body: 'progresswatch space use {{space}}',
          only: :with_space
        },
        {
          label: 'create_a_task_where_the_work_starts_and_keep_the_uuid',
          body: 'TASK=$(progresswatch new "Crawl docs")'
        },
        {
          label: 'report_as_it_moves_this_is_the_call_that_goes_in_your_loop',
          body: 'progresswatch update $TASK --current 1200 --end 50000 --values pages=1200'
        },
        {
          label: 'close_it_this_is_what_sends_the_notification',
          body: 'progresswatch done $TASK'
        },
        {
          label: 'or_wrap_a_process_that_is_not_yours_to_change',
          body: 'progresswatch run "python train.py"'
        },
        {
          label: 'in_ci_there_is_no_config_file_to_write',
          body: 'export PROGRESSWATCH_SERVER="{{server}}" PROGRESSWATCH_SPACE="{{space}}"'
        }
      ]
    },

    'agent' => {
      heading: 'give_an_ai_agent_a_progress_skill',
      description: 'give_an_ai_agent_a_skill_for_reporting_its_own_progress',
      title: 'agent_skill',
      icon: 'robot',
      intro: 'the_skill_drives_the_cli_so_the_agent_needs_no_server_or_uuid_of_its_own',
      steps: [
        {
          label: 'install_the_cli_the_skill_is_a_set_of_instructions_for_driving_it',
          body: 'npm install -g progresswatch'
        },
        {
          label: 'point_it_at_this_server_saved_to_progresswatchrc',
          body: 'progresswatch configure --server {{server}}',
          only: :self_hosted
        },
        {
          label: 'create_a_space_for_the_agent_to_report_into',
          body: 'progresswatch space new "Agent work"',
          only: :without_space
        },
        {
          label: 'point_it_at_this_space_use_local_to_bind_it_to_one_project',
          body: 'progresswatch space use {{space}}',
          only: :with_space
        },
        {
          label: 'install_the_skill_it_knows_75_agents',
          body: 'npx skills add progress-watch/progresswatch-cli'
        },
        { label: 'that_is_all_the_agent_decides_on_its_own_when_work_is_worth_tracking' }
      ]
    },

    'mcp' => {
      heading: 'connect_an_agent_over_mcp',
      description: 'connect_an_ai_agent_to_progress_watch_over_mcp',
      title: 'mcp',
      icon: 'plug',
      steps: [
        {
          label: 'add_the_server',
          body: 'claude mcp add --transport http progress-watch {{server}}/mcp/{{space}}'
        },
        {
          label: 'or_write_it_into_mcp_json_yourself',
          body: MCP_IN_URL
        },
        {
          label: 'the_space_uuid_sits_in_the_url_so_any_client_that_takes_only_a_url_works',
          body: MCP_IN_HEADER
        },
        { label: 'four_tools_create_space_create_task_update_task_complete_task' }
      ]
    },

    'curl' => {
      heading: 'try_the_api_with_curl',
      description: 'try_the_api_with_curl_and_report_from_a_client_that_can_only_fire_a_url',
      title: 'curl',
      icon: 'globe',
      steps: [
        {
          label: 'create_a_space_keep_its_uuid_whoever_has_it_can_read_and_write_here',
          body: 'SPACE_UUID=$(curl -s -X POST {{server}}/spaces ' \
                "-H 'Content-Type: application/json' -d '{\"title\": \"My work\"}' | jq -r .uuid)",
          only: :without_space
        },
        {
          label: 'create_a_task_keep_its_uuid',
          body: 'TASK=$(curl -s -X POST {{server}}/spaces/{{space}}/tasks ' \
                "-H 'Content-Type: application/json' -d '{\"title\": \"Crawl docs\"}' | jq -r .uuid)"
        },
        {
          label: 'report_progress_every_write_replaces_the_whole_state',
          body: "curl -X PUT {{server}}/tasks/$TASK -H 'Content-Type: application/json' " \
                "-d '{\"current\": 1200, \"end\": 50000, \"values\": {\"pages\": 1200, \"errors\": 3}}'"
        },
        {
          label: 'finish_it_this_is_what_sends_the_notification',
          body: "curl -X PUT {{server}}/tasks/$TASK -H 'Content-Type: application/json' -d '{\"done\": true}'"
        },
        { label: 'that_is_the_whole_surface_and_it_is_what_the_cli_and_the_mcp_tools_call' },
        {
          label: 'one_more_for_a_client_that_cannot_do_the_above',
          body: 'curl -g "{{server}}/tasks/$TASK/report?current=1200&end=50000&values[errors]=3"'
        },
        { label: 'the_g_is_for_curl_not_for_us' },
        { label: 'use_it_only_when_there_is_no_alternative_it_is_a_get_that_writes' }
      ]
    },

    'docker' => {
      heading: 'self_host_progress_watch_with_docker',
      description: 'the_docker_compose_file_for_running_your_own_server',
      title: 'docker',
      icon: 'container',
      intro: 'your_own_server_on_your_own_box',
      steps: [
        {
          label: 'save_this_as_docker_compose_yml_it_runs_the_published_image',
          body: COMPOSE
        },
        {
          label: 'generate_a_secret_and_paste_it_over_the_placeholder',
          body: 'openssl rand -hex 64'
        },
        {
          label: 'start_it_the_app_a_worker_for_notifications_a_redis_and_a_sqlite_file',
          body: 'docker compose up -d'
        },
        {
          label: 'then_point_the_cli_at_it_this_page_is_served_from_server',
          body: 'export PROGRESSWATCH_SERVER="http://localhost:7979"'
        },
        { label: 'that_is_a_working_server_notifications_postgres_and_the_one_click_deploy' }
      ]
    }
  }.freeze

  module_function

  def call(section, base_url:, space_uuid: nil, hosted: ProgressWatch.multitenant?)
    here = [hosted ? :hosted : :self_hosted, space_uuid ? :with_space : :without_space]

    SECTIONS.fetch(section)[:steps]
            .select { |step| step[:only].nil? || here.include?(step[:only]) }
            .map do |step|
              { label: fill(I18n.t(step[:label]), base_url, space_uuid),
                body: fill(step[:body], base_url, space_uuid) }
            end
  end

  def fill(value, base_url, space_uuid)
    value&.gsub('{{server}}', base_url)&.gsub('{{space}}', space_uuid || PLACEHOLDER)
  end
end
