# frozen_string_literal: true

require 'rails_helper'

# Every page under /docs has a markdown twin for an agent that asks for one. Two ways in,
# because a client that can set a header is not the same client as one that can only build
# a URL.
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

    # A template that reached for a partial built for the web would render markup into
    # something nothing will parse it out of again.
    it "carries no markup on #{path}" do
      get "#{path}.md"

      expect(response.body).not_to match(/<(div|p|span|a|table|clipboard-copy)\b/)
    end
  end

  # There is no translated markdown, so the language a request asks for cannot change what
  # it gets. The locale prefix is the harder half: it is the one thing that overrides the
  # cookie and the header everywhere else.
  it 'is English whatever asked for it' do
    get '/docs/notifications.md'
    english = response.body

    get '/de/docs/notifications', headers: { 'Accept' => 'text/markdown', 'Accept-Language' => 'de' }

    expect(response.body).to eq(english)
  end

  # The root dispatches a browser to a space and has no prose to convert, so its markdown
  # is the document everything else links to rather than a status. Both spellings, because
  # `/.md` is not a path and a client that cannot set a header has nowhere else to go.
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

  # head, not the error page: that page is HTML, and a 404 carrying markup would be parsed
  # as the document that was asked for.
  it 'answers an unknown section with an empty 404' do
    get '/docs/nonsense.md'

    expect(response).to have_http_status(:not_found)
    expect(response.body).to be_empty
  end

  # A page added to the sidebar and forgotten here would be invisible to anything reading
  # the markdown, which has no sidebar to notice it is missing from.
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

  # The rest of the web UI is pinned to HTML in the routes. Left to Rails it answered two
  # different wrong things: 406 where the action renders implicitly, and a raise where it
  # renders with an explicit `layout:` — which is `/s/new` and both other modals.
  it 'answers every other page in HTML' do
    space = create_space

    ['/s/new', "/s/#{space.uuid}", "/s/#{space.uuid}/edit", "/s/#{space.uuid}/link"].each do |path|
      get path, headers: { 'Accept' => 'text/markdown' }

      expect(response).to have_http_status(:ok), "#{path} answered #{response.status}"
      expect(response.media_type).to eq('text/html')
    end
  end

  # The other half of the same pin: `format: false`, so a `.md` appended to a space URL is
  # a path that does not route rather than a format the page has no template for.
  it 'does not route a markdown suffix on a page that has none' do
    get "/s/#{create_space.uuid}.md"

    expect(response).to have_http_status(:not_found)
  end
end
