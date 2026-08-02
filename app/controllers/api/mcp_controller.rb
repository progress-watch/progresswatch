# frozen_string_literal: true

# Streamable HTTP transport, stateless: no Mcp-Session-Id, and every request answered
# as application/json rather than an SSE stream. The spec permits both.
module Api
  class McpController < ApplicationController
    # Must keep including the version Mcp::HandleRequest advertises, or the server would
    # reject clients that took it at its word.
    SUPPORTED_PROTOCOL_VERSIONS = %w[2025-06-18 2025-03-26 2024-11-05].freeze

    # 405 is the spec's answer for a server that opens no server-initiated stream.
    def show
      head :method_not_allowed
    end

    def create
      return render_protocol_version_error unless supported_protocol_version?

      message = parsed_message

      return render(json: Mcp::HandleRequest.invalid_request, status: :bad_request) if message.nil?

      response_body = Mcp::HandleRequest.call(message, space_uuid: space_uuid, base_url: request.base_url)

      return head :accepted if response_body.nil?

      render json: response_body
    end

    private

    # The header is for clients that accept only a bare URL.
    def space_uuid
      params[:space_uuid].presence || request.headers['X-Space-Uuid'].presence
    end

    def parsed_message
      parsed = JSON.parse(request.body.read)

      # Batching was removed in protocol version 2025-06-18.
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end

    def supported_protocol_version?
      requested = request.headers['MCP-Protocol-Version']

      requested.blank? || SUPPORTED_PROTOCOL_VERSIONS.include?(requested)
    end

    def render_protocol_version_error
      render json: {
        error: "Unsupported MCP-Protocol-Version. This server speaks #{SUPPORTED_PROTOCOL_VERSIONS.join(', ')}."
      }, status: :bad_request
    end
  end
end
