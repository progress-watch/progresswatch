# frozen_string_literal: true

require 'rails_helper'

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

  it 'keeps the refusal in the document and off the page' do
    get '/openapi.json'
    expect(response.parsed_body.dig('paths', '/tasks/{task_uuid}', 'patch', 'deprecated')).to be(true)

    get '/docs/api'
    expect(response.body).not_to include('id="report-progress-patch"')
  end

  it 'counts the operations correctly in its own opening line' do
    get '/docs/api'

    words = %w[zero one two three four five six seven eight nine ten]

    expect(response.body).to include("#{words.fetch(OpenApi::Operations.call.size).capitalize} operations")
  end

  it 'lists them in the order it was told to, not hash order' do
    expect(OpenApi::Operations.call.pluck(:id))
      .to eq(OpenApi::Operations::ORDER)
  end

  it 'names a referenced schema instead of following it' do
    expect(OpenApi::Operations.type_label({ 'type' => 'array',
                                            'items' => { '$ref' => '#/components/schemas/Task' } })).to eq('Task[]')
  end
end
