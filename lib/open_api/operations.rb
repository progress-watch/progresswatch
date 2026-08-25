# frozen_string_literal: true

module OpenApi
  module Operations
    ORDER = %w[create-space create-task report-progress report-progress-from-url get-space get-task health].freeze

    HIDDEN = ['report-progress-patch'].freeze

    module_function

    def call
      PATHS.flat_map { |path, methods| methods.map { |verb, operation| build(path, verb, operation) } }
           .reject { |operation| HIDDEN.include?(operation[:id]) }
           .sort_by { |operation| ORDER.index(operation[:id]) || ORDER.size }
    end

    def build(path, verb, operation)
      {
        id: operation['operationId'].underscore.dasherize,
        method: verb,
        path:,
        summary: operation['summary'],
        description: operation['description'],
        parameters: operation['parameters'] || [],
        request_body: schema_of(operation.dig('requestBody', 'content')),
        example: operation.dig('requestBody', 'content', 'application/json', 'example'),
        responses: operation['responses'].map { |status, response| response_for(status, response) }
      }
    end

    def response_for(status, response)
      { status:, description: response['description'], schema: schema_of(response['content']) }
    end

    # One level only. Task.children items are Task again, so expanding a $ref inside a
    # property would not terminate; the name is what a reader needs there anyway.
    def type_label(schema)
      return 'object' if schema.nil?
      return schema['$ref'].split('/').last if schema['$ref']

      type = Array(schema['type']).reject { |name| name == 'null' }.first || 'object'
      label = type == 'array' ? "#{type_label(schema['items'])}[]" : type

      Array(schema['type']).include?('null') ? "#{label} | null" : label
    end

    def optional?(schema, name)
      Array(schema['required']).exclude?(name)
    end

    def schema_of(content)
      schema = content&.dig('application/json', 'schema')
      return nil if schema.nil?

      ref = schema['$ref']
      ref ? SCHEMAS.fetch(ref.split('/').last) : schema
    end
  end
end
