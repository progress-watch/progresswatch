# frozen_string_literal: true

module ApiHelpers
  def json
    JSON.parse(response.body)
  end

  def post_json(path, payload)
    post path, params: payload.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
  end

  def put_json(path, payload)
    put path, params: payload.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
  end

  def create_space(title: 'Test space')
    Spaces::Create.call(title: title)
  end

  def create_task(space, title: nil, source: nil, parent_uuid: nil)
    Tasks::Create.call(space: space, title: title, source: source, parent_uuid: parent_uuid)
  end
end

RSpec.configure { |config| config.include ApiHelpers }
