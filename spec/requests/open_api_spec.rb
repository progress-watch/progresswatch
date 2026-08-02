# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OpenAPI' do
  let(:document) { response.parsed_body }

  def shape(path)
    path.gsub(/\{\w+\}/, '{}')
  end

  def served_routes
    Rails.application.routes.routes.filter_map do |route|
      controller = route.defaults[:controller].to_s
      next unless controller.start_with?('api/') || controller == 'health'
      next if %w[api/mcp api/open_api].include?(controller)

      [route.path.spec.to_s.sub('(.:format)', '').gsub(/:(\w+)/, '{\1}'), route.verb.downcase]
    end.uniq
  end

  before { get '/openapi.json' }

  it 'serves the same document as YAML' do
    json = document

    get '/openapi.yml'

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/yaml')
    expect(YAML.safe_load(response.body)).to eq(json)
  end

  it 'is served as JSON and names its version' do
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('application/json')
    expect(document['openapi']).to start_with('3.1')
    expect(document['servers'].first['url']).to eq('http://www.example.com')
  end

  # Hand-written, so what rots is the correspondence with the app. These two walk it in
  # both directions. Compared with the parameter names blanked, because a path parameter
  # is named independently on each side and the URL is the same either way.
  it 'documents a path for every JSON route the app actually serves' do
    documented = document['paths'].flat_map { |path, verbs| verbs.keys.map { |verb| [shape(path), verb] } }

    served_routes.each do |path, verb|
      expect(documented).to include([shape(path), verb]), "#{verb.upcase} #{path} is not in the document"
    end
  end

  it 'documents nothing the app does not serve' do
    served = served_routes.map { |path, verb| [shape(path), verb] }

    document['paths'].each do |path, verbs|
      verbs.each_key do |verb|
        expect(served).to include([shape(path), verb]), "#{verb.upcase} #{path} is documented but not routed"
      end
    end
  end

  it 'declares a parameter for every placeholder in a path' do
    document['paths'].each do |path, verbs|
      placeholders = path.scan(/\{(\w+)\}/).flatten

      verbs.each do |verb, operation|
        declared = operation.fetch('parameters', []).map { |parameter| parameter['name'] }

        expect(declared).to match_array(placeholders), "#{verb.upcase} #{path} declares #{declared}"
      end
    end
  end

  # Generators name their methods after these, so a missing or duplicated one produces a
  # client with a method called `spaces_space_uuid_get`.
  it 'gives every operation a unique operationId' do
    ids = document['paths'].values.flat_map { |verbs| verbs.values.map { |operation| operation['operationId'] } }

    expect(ids).to all(be_present)
    expect(ids.uniq).to eq(ids)
  end

  # The schemas were written by reading the serializers; this asserts they still match.
  it 'describes a task exactly as the API returns one' do
    space = create_space
    parent = create_task(space, title: 'Deploy')
    create_task(space, title: 'Build', parent_uuid: parent.uuid)
    Tasks::Report.call(parent, current: 1, end_value: 2)

    get "/tasks/#{parent.uuid}"
    task = response.parsed_body

    get '/openapi.json'
    schema = document['components']['schemas']['Task']

    expect(task.keys).to match_array(schema['properties'].keys)
    expect(task.keys).to match_array(schema['required'])
    expect(task['progress'].keys).to match_array(document['components']['schemas']['Progress']['properties'].keys)
  end

  it 'describes a space exactly as the API returns one' do
    space = create_space

    get "/spaces/#{space.uuid}"
    body = response.parsed_body

    get '/openapi.json'
    schema = document['components']['schemas']['Space']

    expect(body.keys).to match_array(schema['properties'].keys)
  end

  # 3.0 spelled a nullable field `nullable: true`; 3.1 is JSON Schema and spells it in the
  # type. Getting this wrong makes generators emit non-null types for fields that are null
  # most of the time.
  it 'spells nullable the 3.1 way' do
    expect(document.to_s).not_to include('nullable')
    expect(document['components']['schemas']['Task']['properties']['finished_at']['type']).to eq(%w[string null])
  end
end
