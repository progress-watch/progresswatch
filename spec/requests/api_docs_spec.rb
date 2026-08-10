# frozen_string_literal: true

require 'rails_helper'

# The page is generated from OpenApi::PATHS, so the thing that can still rot is the
# ordering list — an endpoint added to the document and left out of ORDER would render
# last and silently, which reads like a page that forgot it.
RSpec.describe 'API reference' do
  it 'renders every operation the document defines, except the ones it hides' do
    get '/docs/api'

    expect(response).to have_http_status(:ok)

    OpenApi::PATHS.each do |path, methods|
      methods.each_value do |operation|
        anchor = operation['operationId'].underscore.dasherize
        next if OpenApi::Operations::HIDDEN.include?(anchor)

        expect(response.body).to include(%(id="#{anchor}")), "#{path} is in the document but not on the page"
        expect(response.body).to include(ERB::Util.html_escape(operation['summary']))
      end
    end
  end

  # PATCH is routed and documented so it can answer 405 with a reason. It is not something
  # a reader can call, so it is not a row in the sidebar — but it must stay in the document,
  # where a spec walks routes in both directions.
  it 'keeps the refusal in the document and off the page' do
    get '/openapi.json'
    expect(response.parsed_body.dig('paths', '/tasks/{task_uuid}', 'patch', 'deprecated')).to be(true)

    get '/docs/api'
    expect(response.body).not_to include('id="report-progress-patch"')
  end

  # The count is prose and nothing recomputes it, so adding an endpoint leaves it wrong on
  # the one page a reader is counting from.
  it 'counts the operations correctly in its own opening line' do
    get '/docs/api'

    words = %w[zero one two three four five six seven eight nine ten]

    expect(response.body).to include("#{words.fetch(OpenApi::Operations.call.size).capitalize} operations")
  end

  it 'lists them in the order it was told to, not hash order' do
    expect(OpenApi::Operations.call.pluck(:id))
      .to eq(OpenApi::Operations::ORDER)
  end

  # Task.children is an array of Task. Expanding a $ref inside a property would not
  # terminate, so the label is the name.
  it 'names a referenced schema instead of following it' do
    expect(OpenApi::Operations.type_label({ 'type' => 'array',
                                            'items' => { '$ref' => '#/components/schemas/Task' } })).to eq('Task[]')
  end
end
