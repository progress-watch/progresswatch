# frozen_string_literal: true

module Mcp
  module HandleRequest
    UnknownMethod = Class.new(StandardError)
    UnknownTool = Class.new(StandardError)

    INSTRUCTIONS = <<~TEXT
      This connection reports into a space the user opened to watch the work done in this
      project from anywhere. Report your own work here without being asked: anything that
      edits files or runs commands gets a task.

      - create_task when the work starts, and one child per step with parent_uuid.
      - update_task as each step moves, and complete_task as each step ends, not in a sweep
        at the end. A board that stays empty until the job is over tells the user nothing.
      - complete_task the parent last. Completing is what sends the user a notification, so
        complete work that failed too, with the failure in values.
    TEXT

    module_function

    def call(message, space_uuid:, base_url:)
      return invalid_request unless message.is_a?(Hash)

      id = message['id']
      return nil if id.nil?

      success(id, dispatch(message['method'], message['params'] || {}, space_uuid, base_url))
    rescue UnknownMethod => e
      error(id, -32_601, e.message)
    rescue UnknownTool, Tools::MissingSpace => e
      error(id, -32_602, e.message)
    rescue ActiveRecord::RecordNotFound
      success(id, Tools.error('No such task or space on this server.'))
    rescue ActiveRecord::RecordInvalid => e
      success(id, Tools.error(e.record.errors.full_messages.to_sentence))
    rescue TaskStates::InvalidValues => e
      success(id, Tools.error(e.message))
    end

    def dispatch(method, params, space_uuid, base_url)
      case method
      when 'initialize' then initialize_result(space_uuid)
      when 'tools/list' then { 'tools' => Tools::DEFINITIONS }
      when 'tools/call' then tools_call(params, space_uuid, base_url)
      when 'ping' then {}
      else raise UnknownMethod, "Unknown method: #{method}"
      end
    end

    def initialize_result(space_uuid)
      {
        'protocolVersion' => '2025-06-18',
        'capabilities' => { 'tools' => {} },
        'serverInfo' => { 'name' => 'progress-watch', 'version' => '0.1.0' },
        'instructions' => (INSTRUCTIONS if space_uuid.present?)
      }.compact
    end

    def tools_call(params, space_uuid, base_url)
      name = params['name']
      raise UnknownTool, "Unknown tool: #{name}" unless Tools.exists?(name)

      Tools.call(name, params['arguments'] || {}, space_uuid: space_uuid, base_url: base_url)
    end

    def success(id, result)
      { 'jsonrpc' => '2.0', 'id' => id, 'result' => result }
    end

    def error(id, code, message)
      { 'jsonrpc' => '2.0', 'id' => id, 'error' => { 'code' => code, 'message' => message } }
    end

    def invalid_request
      error(nil, -32_600, 'Expected a single JSON-RPC 2.0 message object')
    end
  end
end
