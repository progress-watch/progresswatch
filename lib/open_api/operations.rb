# frozen_string_literal: true

# The reference page is generated from the same hash the document is served from, so an
# endpoint cannot be documented on the site and missing from /openapi.json or the reverse.
module OpenApi
  module Operations
    # Reading order, not method order: this is the sequence somebody integrating actually
    # calls them in. Anything not listed lands at the end rather than disappearing.
    ORDER = %w[create-space create-task report-progress get-space get-task health].freeze

    # PATCH is routed on purpose so it can answer 405 with a reason instead of a bare 404,
    # and it is in the document because the spec walks routes in both directions. It is not
    # an operation, though: on the page it took a slot beside six real ones under the word
    # "Rejected", and the refusal is already a sentence in the intro. Marked `deprecated`
    # in the document so a generator flags it rather than emitting a method that cannot work.
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

      # Whether a field can come back null is the thing a client author has to handle, so
      # it belongs in the type rather than being stripped for tidiness.
      Array(schema['type']).include?('null') ? "#{label} | null" : label
    end

    def optional?(schema, name)
      Array(schema['required']).exclude?(name)
    end

    # $refs are resolved here rather than in the template: a reader wants the shape, and
    # following a pointer is the document's problem, not theirs.
    def schema_of(content)
      schema = content&.dig('application/json', 'schema')
      return nil if schema.nil?

      ref = schema['$ref']
      ref ? SCHEMAS.fetch(ref.split('/').last) : schema
    end
  end
end
