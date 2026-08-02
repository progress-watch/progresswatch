# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Web UI' do
  describe 'GET /' do
    it 'renders the landing page' do
      get '/'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Create a space')
    end

    # `/` is a dispatcher: space-router sends a browser that already knows a space
    # straight to it, so the page ships hidden. Without JavaScript nothing routes and
    # the create form is the only way in, which is what the noscript rule is for.
    it 'ships both landing branches hidden, with a noscript rule that reveals the pitch' do
      get '/'

      expect(response.body).to include('<div data-landing hidden>')
      expect(response.body).to include('data-spaces hidden')
      expect(response.body).to include('[data-landing][hidden] { display: block }')
    end

    # The grid page is only the grid. Everything else on `/` belongs to the branch a
    # browser that already knows several spaces never sees.
    it 'keeps how-it-works and open-existing out of the grid branch' do
      get '/'

      grid = response.body[%r{<space-list.*?</space-list>}m]

      expect(grid).to be_present
      expect(grid).not_to include('How it works', 'Open an existing space')
    end

    it 'does not repeat the credential warning in a footer' do
      get '/'

      expect(response.body).not_to include('<footer')
    end

    # In the navbar, so it is reachable from a dashboard too — the landing page is a
    # dispatcher now and a browser that knows a space never sees its create form.
    it 'carries a new-space modal in the header' do
      get '/'

      expect(response.body).to include('<modal-button data-target="new-space">')
      expect(response.body).to include('<dialog id="new-space"')
      expect(response.body).to match(/<form[^>]+action="#{dashboards_path}"[^>]+method="post"/)
    end

    # A missing layout is silent: the page still renders and still returns 200, it
    # just arrives with no stylesheet and no JavaScript. Assert the tags exist.
    it 'renders inside the layout, with the asset tags' do
      get '/'

      # The test environment builds into packs-test, production into packs.
      expect(response.body).to include('<!DOCTYPE html>')
      expect(response.body).to match(%r{<script[^>]+src="/packs(-test)?/js/application[^"]*"})
      expect(response.body).to match(%r{<link[^>]+href="/packs(-test)?/css/application[^"]*"})
    end
  end

  describe 'POST /s' do
    it 'creates a space and redirects into its dashboard' do
      expect { post '/s', params: { title: 'Production' } }.to change(Space, :count).by(1)

      # Not Space.last — the primary key is a random uuid, so it returns an arbitrary
      # row. Follow the redirect the controller actually issued.
      expect(response).to redirect_to(%r{/s/[0-9a-f-]{36}\z})
      expect(Space.find(response.location[/[0-9a-f-]{36}\z/]).title).to eq('Production')
    end
  end

  describe 'GET /s/:uuid' do
    let(:space) { create_space(title: 'Production') }

    it 'renders the dashboard' do
      get dashboard_path(space.uuid)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Production')
    end

    # Opening the page records the space in this browser, so the page also has to
    # offer a way back out of that.
    it 'both remembers the space and offers to forget it' do
      get dashboard_path(space.uuid)

      expect(response.body).to include("<remember-space data-uuid=\"#{space.uuid}\"")
      expect(response.body).to include("<forget-space data-uuid=\"#{space.uuid}\"")
    end

    it 'shows the icon and offers a rename modal' do
      Spaces::Update.call(space, icon: '🌙')

      get dashboard_path(space.uuid)

      expect(response.body).to include('🌙')
      expect(response.body).to include('<modal-button data-target="edit-space"')
    end

    it 'offers the space link for copying, not just the uuid' do
      get dashboard_path(space.uuid)

      expect(response.body).to include(%(data-text="#{dashboard_url(space.uuid)}"))
    end

    # The snippets are onboarding. Once anything has reported they are noise, and the
    # navbar still has them.
    it 'drops the reporting instructions once the space has a task' do
      get dashboard_path(space.uuid)
      expect(response.body).to include('Report into this space')

      create_task(space, title: 'Anything')

      get dashboard_path(space.uuid)
      expect(response.body).not_to include('Report into this space')
    end

    # A mistyped UUID and a real one must look the same from outside. There is no
    # "exists but not yours" state to probe at, because there are no accounts.
    it 'renders a not-found page for an unknown space rather than raising' do
      get dashboard_path(SecureRandom.uuid)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('No such space')
    end
  end

  describe 'GET /s/:uuid/tasks' do
    let(:space) { create_space }
    let(:frame_request) { { 'Turbo-Frame' => 'tasks' } }

    # The frame's response has no layout, so opened directly it is an unstyled
    # fragment. That is a URL a person can land on, and it must not look broken.
    it 'sends a person who opens it directly to the dashboard' do
      get tasks_dashboard_path(space.uuid)

      expect(response).to redirect_to(dashboard_path(space.uuid))
    end

    # Turbo rejects a frame whose response points back at the URL it was fetched
    # from, and does it by silently rendering nothing at all.
    it 'answers with a frame that does not reference itself' do
      get tasks_dashboard_path(space.uuid), headers: frame_request

      expect(response.body).to include('<turbo-frame id="tasks">')
      expect(response.body).not_to include(tasks_dashboard_path(space.uuid))
    end

    it 'renders the three progress states apart' do
      finished = create_task(space, title: 'Finished work')
      Tasks::Report.call(finished, current: 10, end_value: 10)

      at_zero = create_task(space, title: 'Just started')
      Tasks::Report.call(at_zero, current: 0, end_value: 100)

      create_task(space, title: 'Never reported')

      get tasks_dashboard_path(space.uuid), headers: frame_request

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Waiting for data…')
      expect(response.body).to include('0.0%')
      expect(response.body).to include('finished in')
    end

    it 'nests children under their parent and shows the aggregate' do
      parent = create_task(space, title: 'Deploy')
      build = create_task(space, title: 'Build', parent_uuid: parent.uuid)
      create_task(space, title: 'Test', parent_uuid: parent.uuid)
      Tasks::Report.call(build, current: 10, end_value: 10)

      get tasks_dashboard_path(space.uuid), headers: frame_request

      expect(response.body).to include('Deploy', 'Build', 'Test')
      # One of two children finished: the parent reads 50%, not its own numbers.
      expect(response.body).to include('1/2 done', '50.0%')
    end

    it 'collapses the steps of a finished parent and leaves an active one open' do
      running = create_task(space, title: 'Running')
      create_task(space, title: 'Step of running', parent_uuid: running.uuid)

      done = create_task(space, title: 'Done')
      child = create_task(space, title: 'Step of done', parent_uuid: done.uuid)
      Tasks::Report.call(child, current: 1, end_value: 1)
      Tasks::Report.call(done, done: true)

      get tasks_dashboard_path(space.uuid), headers: frame_request

      running_steps, done_steps = response.body.scan(/<details[^>]*>/)

      expect(running_steps).to include('open')
      expect(done_steps).not_to include('open')
    end

    # Ordering is the client's job — the serializer keeps creation order, so both rules
    # have to be applied here: finished last, and newest first inside each group.
    it 'renders active before finished, and newest first within each' do
      # Interleaved on purpose: creation order alone must not decide the grouping.
      %w[first second].each do |title|
        create_task(space, title: "Running #{title}")
        Tasks::Report.call(create_task(space, title: "Done #{title}"), done: true)
      end

      get tasks_dashboard_path(space.uuid), headers: frame_request

      expect(response.body.scan(/(?:Running|Done) (?:first|second)/))
        .to eq(['Running second', 'Running first', 'Done second', 'Done first'])
    end
  end

  describe 'GET /connect/:section' do
    it 'fills the space uuid into the snippet when one is given' do
      space = create_space

      get connect_path('cli', space: space.uuid)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(space.uuid)
    end

    it 'falls back to a placeholder without one' do
      get connect_path('curl')

      expect(response.body).to include(ERB::Util.html_escape(ConnectSnippets::PLACEHOLDER))
    end

    # Constrained in the routes, so an arbitrary path segment never reaches a lookup.
    it 'rejects an unknown section' do
      get '/connect/nonsense'

      expect(response).to have_http_status(:not_found)
    end
  end

  # The browser is a client like any other: it must not be able to negotiate the API
  # into HTML, or the CLI and the app would start receiving pages instead of JSON.
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
