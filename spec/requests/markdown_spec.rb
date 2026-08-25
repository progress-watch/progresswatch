# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Markdown docs' do
  pages = ['/docs', '/docs/api', *ConnectSnippets::SECTIONS.keys.map { |slug| "/docs/#{slug}" },
           *Docs::DOCUMENTS.map { |doc| "/docs/#{doc[:slug]}" }]

  pages.each do |path|
    it "serves #{path} as markdown, by suffix and by header" do
      get "#{path}.md"
      by_suffix = response.body

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/markdown')
      expect(by_suffix).to start_with('# ')

      get path, headers: { 'Accept' => 'text/markdown' }

      expect(response.media_type).to eq('text/markdown')
      expect(response.body).to eq(by_suffix)
    end

    it "carries no markup on #{path}" do
      get "#{path}.md"

      expect(response.body).not_to match(/<(div|p|span|a|table|clipboard-copy)\b/)
    end
  end

  it 'ignores Accept-Language' do
    get '/docs/notifications.md'
    english = response.body

    get '/docs/notifications', headers: { 'Accept' => 'text/markdown', 'Accept-Language' => 'de' }

    expect(response.body).to eq(english)
  end

  it 'has nothing under a locale prefix' do
    get '/de/docs/notifications.md'

    expect(response).to have_http_status(:not_found)
    expect(response.body).to be_empty

    get '/de/docs', headers: { 'Accept' => 'text/markdown' }

    expect(response).to have_http_status(:not_found)
  end

  it 'still serves the German page as markup' do
    get '/de/docs/notifications'

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/html')
  end

  it 'answers the root with the docs index' do
    get '/docs.md'
    docs = response.body

    get '/', headers: { 'Accept' => 'text/markdown' }

    expect(response.media_type).to eq('text/markdown')
    expect(response.body).to eq(docs)

    get '/index.md'

    expect(response.media_type).to eq('text/markdown')
    expect(response.body).to eq(docs)
  end

  it 'still dispatches a browser at the root' do
    get '/'

    expect(response.media_type).to eq('text/html')
    expect(response.body).to include('<template data-template="card">')
  end

  it 'answers an unknown section with an empty 404' do
    get '/docs/nonsense.md'

    expect(response).to have_http_status(:not_found)
    expect(response.body).to be_empty
  end

  it 'links every section from the index' do
    get '/docs.md'

    (ConnectSnippets::SECTIONS.keys + Docs::DOCUMENTS.map { |doc| doc[:slug] }).each do |slug|
      expect(response.body).to include("/docs/#{slug}.md")
    end

    expect(response.body).to include('/docs/api.md')
  end

  it 'documents every operation in the API reference' do
    get '/docs/api.md'

    OpenApi::Operations.call.each do |operation|
      expect(response.body).to include("## #{operation[:summary]}")
      expect(response.body).to include("`#{operation[:method].upcase} #{operation[:path]}`")
    end
  end

  it 'answers every other page in HTML' do
    space = create_space

    ['/s/new', "/s/#{space.uuid}", "/s/#{space.uuid}/edit", "/s/#{space.uuid}/link"].each do |path|
      get path, headers: { 'Accept' => 'text/markdown' }

      expect(response).to have_http_status(:ok), "#{path} answered #{response.status}"
      expect(response.media_type).to eq('text/html')
    end
  end

  it 'does not route a markdown suffix on a page that has none' do
    get "/s/#{create_space.uuid}.md"

    expect(response).to have_http_status(:not_found)
  end
end
