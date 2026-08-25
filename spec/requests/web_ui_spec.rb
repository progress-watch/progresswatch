# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Web UI' do
  def hosted!
    allow(ProgressWatch).to receive(:multitenant?).and_return(true)
  end

  describe 'GET /' do
    it 'renders the card templates and nothing that would flash before them' do
      get '/'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<template data-template="card">')
      expect(response.body).not_to include('No spaces on this browser')
    end

    it 'hides nothing behind JavaScript' do
      get '/'

      expect(response.body).not_to include('hidden>')
      expect(response.body).not_to include('<noscript')
    end

    it 'is not indexable, and only /docs and the Connect sections are' do
      hosted!
      indexable = %w[/docs /docs/api /docs/cli /docs/curl /docs/agent /docs/mcp /docs/docker
                     /docs/environment-variables]
      rest = ['/', '/s/new', "/s/#{create_space.uuid}/edit", "/s/#{create_space.uuid}", '/docs/nonsense']

      indexable.each do |path|
        get path
        expect(response.body).not_to include('name="robots"'), "#{path} should be indexable"
      end

      rest.each do |path|
        get path
        expect(response.body).to include('<meta name="robots" content="noindex, nofollow">'), "#{path} should not be"
        expect(response.body).not_to include('rel="canonical"'), "#{path} should have no canonical"
      end
    end

    it 'does not repeat the credential warning in a footer' do
      get '/'

      expect(response.body).not_to include('<footer')
    end

    it 'links to the new-space modal instead of embedding it' do
      get '/'

      expect(response.body).to include('<turbo-frame id="modal"></turbo-frame>')
      expect(response.body).to include(%(href="#{new_space_path}"), 'data-turbo-frame="modal"')
      expect(response.body).not_to include('<dialog')
    end

    it 'renders inside the layout, with the asset tags' do
      get '/'

      expect(response.body).to include('<!DOCTYPE html>')
      expect(response.body).to match(%r{<script[^>]+src="/packs(-test)?/js/application[^"]*"})
      expect(response.body).to match(%r{<link[^>]+href="/packs(-test)?/css/application[^"]*"})
    end
  end

  describe 'GET /docs' do
    it 'is the page written to be found, with its own title and description' do
      hosted!

      get '/docs'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<title>Get started | Progress Watch</title>')
      expect(response.body).to include('<link rel="canonical" href="http://www.example.com/docs">')
      expect(response.body).to include('<meta property="og:title"')
      expect(response.body).not_to include('name="robots"')
    end

    it 'keeps the theme in the header rather than the phone menu' do
      get '/docs'

      expect(response.body.scan('<theme-toggle').size).to eq(1)
      expect(response.body.index('<theme-toggle')).to be < response.body.index('class="relative md:hidden"')
    end

    it 'is reachable from both navbars, so it is not only in the sitemap' do
      hosted!

      get '/'

      expect(response.body.scan(%(href="#{docs_path}")).size).to eq(2)
    end
  end

  describe 'self-hosted, which is the default' do
    it 'never names the flag in anything written for a reader' do
      pages = Dir['app/views/docs/*.erb'] + ['README.md']

      pages.each do |page|
        expect(File.read(page)).not_to include('MULTITENANT'), "#{page} names an internal flag"
      end
    end

    it 'links the docs but keeps them out of any index' do
      get '/'
      expect(response.body).to include(%(href="#{docs_path}"))

      get '/docs'
      expect(response.body).to include('<meta name="robots" content="noindex, nofollow">')
      expect(response.body).not_to include('rel="canonical"')
      expect(response.body).not_to include('property="og:')
    end

    it '404s the sitemap' do
      get '/sitemap.xml'

      expect(response).to have_http_status(:not_found)
    end

    it '404s llms.txt, and does not point at it from the head' do
      get '/llms.txt'
      expect(response).to have_http_status(:not_found)

      get '/docs'
      expect(response.body).not_to include('rel="describedby"')
    end

    it 'tells crawlers to stay out entirely, and names no sitemap' do
      get '/robots.txt'

      expect(response.body).to include('Disallow: /')
      expect(response.body).not_to include('Sitemap:')
    end

    it 'promises nothing about deleting an empty space' do
      space = create_space

      get "/s/#{space.uuid}"

      expect(response.body).to include('Report into this space')
      expect(response.body).not_to include('may be deleted')
    end
  end

  describe 'GET /s/new' do
    it 'offers both creating a space and adding one that exists' do
      get new_space_path, headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).to include('<add-space')
      expect(response.body).to include('data-action="submit:add-space#open"')
      expect(response.body).to include(%(action="#{spaces_path}"))
    end
  end

  describe 'POST /s' do
    it 'creates a space and redirects into its dashboard' do
      expect { post '/s', params: { title: 'Production' } }.to change(Space, :count).by(1)

      expect(response).to redirect_to(%r{/s/[0-9a-f-]{36}\z})
      expect(Space.find(response.location[/[0-9a-f-]{36}\z/]).title).to eq('Production')
    end
  end

  describe 'GET /s/:uuid' do
    let(:space) { create_space(title: 'Production') }

    it 'renders the dashboard' do
      get space_path(space.uuid)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Production')
    end

    it 'both remembers the space and offers to forget it' do
      get space_path(space.uuid)

      expect(response.body).to include("<remember-space data-uuid=\"#{space.uuid}\"")
      expect(response.body).to include("<forget-space data-uuid=\"#{space.uuid}\"")
    end

    it 'shows the icon and offers a rename modal' do
      Spaces::Update.call(space, icon: '🌙')

      get space_path(space.uuid)

      expect(response.body).to include('🌙')
      expect(response.body).to include(%(href="#{edit_space_path(space.uuid)}"))
      expect(response.body).not_to include('<dialog')
    end

    it 'offers notifications only when push is configured' do
      get space_path(space.uuid)
      expect(response.body).not_to include('<push-toggle')

      stub_const('ProgressWatch::VAPID_PUBLIC_KEY', 'public')
      stub_const('ProgressWatch::VAPID_PRIVATE_KEY', 'private')

      get space_path(space.uuid)
      expect(response.body).to include('<push-toggle')
      expect(response.body).to include('data-key="public"')
      expect(response.body).to include(%(data-uuid="#{space.uuid}"))
      expect(response.body).to include('data-state="unknown"')
    end

    it 'links to its own connect instructions, uuid already filled in' do
      get space_path(space.uuid)

      expect(response.body).to include(%(href="#{docs_section_path(section: 'cli', space: space.uuid)}"))
    end

    it 'opens a share modal rather than silently copying the link' do
      get space_path(space.uuid)

      expect(response.body).to include(%(href="#{space_link_path(space.uuid)}"), 'data-turbo-frame="modal"')
    end

    it 'shows the link, the uuid and a QR of the link in that modal' do
      get space_link_path(space.uuid), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(value="#{space_url(space.uuid)}"))
      expect(response.body).to include(%(value="#{space.uuid}"))
      expect(response.body).to include('<svg viewBox=', 'aria-label="Link to this space"')
    end

    it 'answers a person with a whole page, not a fragment' do
      get space_link_path(space.uuid)

      expect(response.body).to include('<!DOCTYPE html>', 'Share this space')
      expect(response.body).not_to include('<dialog')
    end

    it 'drops the reporting instructions once the space has a task' do
      get space_path(space.uuid)
      expect(response.body).to include('Report into this space')

      create_task(space, title: 'Anything')

      get space_path(space.uuid)
      expect(response.body).not_to include('Report into this space')
    end

    it 'warns the hosted deployment that an empty space is swept' do
      hosted!

      get space_path(space.uuid)

      expect(response.body).to include('may be deleted at any time')
    end

    it 'renders a not-found page for an unknown space rather than raising' do
      get space_path(SecureRandom.uuid)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('No such space')
    end
  end

  describe 'the GitHub link' do
    it 'is in the navbar on the hosted deployment, at both widths' do
      hosted!

      get docs_path

      expect(response.body.scan(ProgressWatch::REPOSITORY_URL).size).to eq(2)
    end

    it 'is nowhere on a self-hosted instance' do
      get docs_path

      expect(response.body).not_to include(ProgressWatch::REPOSITORY_URL)
    end
  end

  describe 'GET /sitemap.xml' do
    it 'is valid and dates every entry' do
      hosted!

      get '/sitemap.xml'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/xml')

      entries = response.body.scan(%r{<url>\s*<loc>(.*?)</loc>\s*<lastmod>(.*?)</lastmod>\s*</url>}m)
      expect(entries.size).to eq(response.body.scan('<loc>').size)
      expect(entries.map(&:last)).to all(match(/\A\d{4}-\d{2}-\d{2}\z/))
    end

    it 'names every operation the document defines' do
      hosted!

      get '/llms.txt'

      OpenApi::Operations.call.each do |operation|
        expect(response.body).to include(operation[:path].gsub(/\{(\w+?)_uuid\}/, '{\\1}')),
                                 "#{operation[:path]} is in the document but not in llms.txt"
      end
    end

    it 'is pointed at from the head of every page' do
      hosted!

      get '/docs'

      expect(response.body).to include(%(<link rel="describedby" href="#{llms_url}">))
    end

    it 'is served as plain text from the host that answered' do
      hosted!

      get '/llms.txt'

      expect(response.media_type).to eq('text/plain')
      expect(response.body).to include('http://www.example.com/spaces')
    end

    it 'lists every indexable page, and only pages that are indexable' do
      hosted!

      get '/sitemap.xml'
      locs = response.body.scan(%r{<loc>(.*?)</loc>}).flatten

      wanted = [api_docs_url] + [nil, *Locales::ALTERNATES].flat_map do |locale|
        [docs_url(locale:),
         *Docs::DOCUMENTS.map { |doc| docs_section_url(section: doc[:slug], locale:) },
         *ConnectSnippets::SECTIONS.each_key.map { |s| docs_section_url(section: s, locale:) }]
      end

      expect(locs).to match_array(wanted)

      locs.each do |loc|
        get URI.parse(loc).path
        expect(response.body).not_to include('name="robots"'), "#{loc} is in the sitemap but noindex"
      end
    end
  end

  describe 'GET /robots.txt' do
    it 'keeps crawlers off the space paths and points at the sitemap' do
      hosted!

      get '/robots.txt'

      expect(response.media_type).to eq('text/plain')
      expect(response.body).to include('Disallow: /s/', "Sitemap: #{sitemap_url}")
    end
  end

  describe 'GET /s/new and /s/:uuid/edit' do
    let(:space) { create_space(title: 'Production') }

    it 'answers a frame request with a dialog in the modal frame' do
      get new_space_path, headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to have_http_status(:ok)
      expect(response.body.strip).to start_with('<turbo-frame id="modal">')
      expect(response.body).to include('<turbo-modal>', '<dialog class="modal"')
      expect(response.body).not_to include('<!DOCTYPE html>')
    end

    it 'answers a direct visit with a whole page' do
      get new_space_path

      expect(response.body).to include('<!DOCTYPE html>')
      expect(response.body).not_to include('<dialog')
    end

    it 'fills the rename form with what the space already has' do
      Spaces::Update.call(space, icon: '🌙')

      get edit_space_path(space.uuid), headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).to include('value="Production"', 'value="🌙"')
      expect(response.body).to include(%(action="#{space_path(space.uuid)}"))
    end

    it '404s for a space that does not exist' do
      get edit_space_path(SecureRandom.uuid), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /s/:uuid/tasks' do
    let(:space) { create_space }
    let(:frame_request) { { 'Turbo-Frame' => 'tasks' } }

    it 'sends a person who opens it directly to the dashboard' do
      get space_tasks_path(space.uuid)

      expect(response).to redirect_to(space_path(space.uuid))
    end

    it 'answers with a frame that does not reference itself' do
      get space_tasks_path(space.uuid), headers: frame_request

      expect(response.body).to include('<turbo-frame id="tasks">')
      expect(response.body).not_to include(space_tasks_path(space.uuid))
    end

    it 'renders the three progress states apart' do
      finished = create_task(space, title: 'Finished work')
      Tasks::Report.call(finished, current: 10, end_value: 10)

      at_zero = create_task(space, title: 'Just started')
      Tasks::Report.call(at_zero, current: 0, end_value: 100)

      create_task(space, title: 'Never reported')

      get space_tasks_path(space.uuid), headers: frame_request

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Waiting for data…')
      expect(response.body).to include('0.0%')

      get space_tasks_path(space.uuid, state: 'finished'), headers: frame_request

      expect(response.body).to include('finished in')
    end

    it 'nests children under their parent and shows the aggregate' do
      parent = create_task(space, title: 'Deploy')
      build = create_task(space, title: 'Build', parent_uuid: parent.uuid)
      create_task(space, title: 'Test', parent_uuid: parent.uuid)
      Tasks::Report.call(build, current: 10, end_value: 10)

      get space_tasks_path(space.uuid), headers: frame_request

      expect(response.body).to include('Deploy', 'Build', 'Test')
      expect(response.body).to include('1/2 done', '50.0%')
    end

    it 'collapses the steps of a finished parent and leaves an active one open' do
      running = create_task(space, title: 'Running')
      create_task(space, title: 'Step of running', parent_uuid: running.uuid)

      done = create_task(space, title: 'Done')
      child = create_task(space, title: 'Step of done', parent_uuid: done.uuid)
      Tasks::Report.call(child, current: 1, end_value: 1)
      Tasks::Report.call(done, done: true)

      get space_tasks_path(space.uuid), headers: frame_request
      running_steps = response.body.scan(/<details[^>]*>/).first

      get space_tasks_path(space.uuid, state: 'finished'), headers: frame_request
      done_steps = response.body.scan(/<details[^>]*>/).first

      expect(running_steps).to include('open')
      expect(done_steps).not_to include('open')
    end

    it 'keeps finished tasks out of the polled frame, newest first in both' do
      %w[first second].each do |title|
        create_task(space, title: "Running #{title}")
        Tasks::Report.call(create_task(space, title: "Done #{title}"), done: true)
      end

      get space_tasks_path(space.uuid), headers: frame_request

      expect(response.body.scan(/(?:Running|Done) (?:first|second)/))
        .to eq(['Running second', 'Running first'])

      get space_tasks_path(space.uuid, state: 'finished'), headers: frame_request

      expect(response.body.scan(/(?:Running|Done) (?:first|second)/))
        .to eq(['Done second', 'Done first'])
    end

    it 'heads the history with the month a task was created in' do
      task = create_task(space, title: 'Ancient')
      Tasks::Report.call(task, done: true)
      task.update!(created_at: Time.utc(2026, 3, 4))

      get space_tasks_path(space.uuid, state: 'finished'), headers: frame_request

      expect(response.body).to include('March 2026')
    end

    it 'pages the history into a frame outside the polled one' do
      (Spaces::ReadFinishedTasks::PAGE + 1).times do |index|
        Tasks::Report.call(create_task(space, title: "Task #{index}"), done: true)
      end

      get space_tasks_path(space.uuid, state: 'finished'), headers: frame_request

      expect(response.body).to include('Older tasks')
      expect(response.body).to include('<turbo-frame id="history"')
      expect(response.body).to include('data-turbo-frame="history"')
    end

    it 'refuses a history cursor it cannot read' do
      get space_tasks_path(space.uuid, state: 'finished', before: 'whenever'), headers: frame_request

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'GET /docs/cli, on each kind of deployment' do
    it 'omits configure on the hosted site' do
      hosted!

      get docs_section_path(section: 'cli')

      expect(response.body).to include('progresswatch space new')
      expect(response.body).not_to include('progresswatch configure')
    end

    it 'teaches configure everywhere else, naming this host' do
      get docs_section_path(section: 'cli')

      expect(response.body).to include('progresswatch configure --server http://www.example.com')
    end
  end

  describe 'GET /docs, for a reader with no space yet' do
    it 'shows how to create one instead of assuming it' do
      get docs_section_path(section: 'cli')

      expect(response.body).to include('progresswatch space new')
      expect(response.body).not_to include('progresswatch space use')
    end

    it 'creates one with curl too, into the variable the rest of the section uses' do
      get docs_section_path(section: 'curl')

      expect(response.body).to include('SPACE_UUID=$(curl -s -X POST')
      expect(response.body).to include('/spaces/$SPACE_UUID/tasks')
    end

    it 'switches to the space it was given once there is one' do
      space = create_space

      get docs_section_path(section: 'cli', space: space.uuid)

      expect(response.body).to include("progresswatch space use #{space.uuid}")
      expect(response.body).not_to include('progresswatch space new')
    end
  end

  describe 'GET /docs/:section' do
    it 'gives every section its own title and description' do
      seen = ConnectSnippets::SECTIONS.keys.map do |section|
        get docs_section_path(section: section)

        [response.body[%r{<title>(.*?)</title>}, 1], response.body[/<meta name="description" content="(.*?)"/, 1]]
      end

      expect(seen.flatten).to all(be_present)
      expect(seen.uniq.size).to eq(ConnectSnippets::SECTIONS.size)
      expect(seen.map(&:first)).to all(end_with('| Progress Watch'))
    end

    it 'fills the space uuid into the snippet when one is given' do
      space = create_space

      get docs_section_path(section: 'cli', space: space.uuid)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(space.uuid)
    end

    it 'stops being indexable once a real uuid is in the query' do
      get docs_section_path(section: 'cli', space: create_space.uuid)

      expect(response.body).to include('<meta name="robots" content="noindex, nofollow">')
      expect(response.body).not_to include('rel="canonical"')
    end

    it 'falls back to a shell variable when there is no space' do
      get docs_section_path(section: 'curl')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('curl -X PUT')
      expect(response.body).to include(ERB::Util.html_escape('$SPACE_UUID'))
      expect(response.body).not_to include('&lt;SPACE_UUID&gt;')
    end

    it 'renders the not-found page for an unknown section' do
      get '/docs/nonsense'

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('Not found', 'Back to the start')
    end
  end

  describe 'API is pinned to JSON' do
    it 'answers JSON even when the browser asks for HTML' do
      space = create_space

      get "/spaces/#{space.uuid}", headers: { 'HTTP_ACCEPT' => 'text/html,application/xhtml+xml' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
      expect(response.parsed_body['uuid']).to eq(space.uuid)
    end
  end
end
