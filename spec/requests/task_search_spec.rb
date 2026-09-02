# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Searching a space' do
  let(:space) { create_space(title: 'Crawlers') }
  let(:frame) { { 'Turbo-Frame' => 'tasks' } }

  def finish(task)
    Tasks::Report.call(task, done: true)
  end

  it 'narrows both the running list and the history' do
    create_task(space, title: 'Nightly backup')
    create_task(space, title: 'Crawl docs')
    finish(create_task(space, title: 'Weekly backup'))
    finish(create_task(space, title: 'Import feeds'))

    get "/s/#{space.uuid}", params: { q: 'backup' }

    expect(response.body).to include('Nightly backup', 'Weekly backup')
    expect(response.body).not_to include('Crawl docs')
    expect(response.body).not_to include('Import feeds')
  end

  it 'carries the query on both frames, so a poll does not throw it away' do
    create_task(space, title: 'Nightly backup')

    get "/s/#{space.uuid}", params: { q: 'backup' }

    running = space_tasks_path(space.uuid, q: 'backup')
    finished = space_tasks_path(space.uuid, state: 'finished', q: 'backup')

    expect(response.body).to include(%(src="#{ERB::Util.html_escape(running)}"))
    expect(response.body).to include(%(src="#{ERB::Util.html_escape(finished)}"))
  end

  it 'keeps the query on the link to older tasks' do
    (Spaces::ReadFinishedTasks::PAGE + 1).times { |index| finish(create_task(space, title: "Backup #{index}")) }

    get "/s/#{space.uuid}/tasks", params: { state: 'finished', q: 'backup' }, headers: { 'Turbo-Frame' => 'finished' }

    expect(response.body).to include('q=backup')
  end

  it 'offers the field only once a space holds enough to be worth searching' do
    (SpacesController::SEARCH_FROM - 1).times { |index| create_task(space, title: "Task #{index}") }

    get "/s/#{space.uuid}"
    expect(response.body).not_to include('id="task-search"')

    create_task(space, title: 'One more')

    get "/s/#{space.uuid}"
    expect(response.body).to include('id="task-search"')
  end

  it 'keeps the field while a search is on, however little it matched' do
    SpacesController::SEARCH_FROM.times { |index| create_task(space, title: "Task #{index}") }

    get "/s/#{space.uuid}", params: { q: 'Task 3' }

    expect(response.body).to include('value="Task 3"')
  end

  it 'answers a fruitless search plainly, without offering the Connect snippets' do
    create_task(space, title: 'Crawl docs')

    get "/s/#{space.uuid}", params: { q: 'backup' }

    expect(response.body).to include('Nothing matches backup')
    expect(response.body).not_to include('Report into this space')
    expect(response.body).not_to include('Nothing running')
  end

  it 'still offers the snippets to a space that is simply empty' do
    get "/s/#{space.uuid}"

    expect(response.body).to include('Report into this space')
  end

  it 'honours the query on the polled frame itself' do
    create_task(space, title: 'Nightly backup')
    create_task(space, title: 'Crawl docs')

    get "/s/#{space.uuid}/tasks", params: { q: 'backup' }, headers: frame

    expect(response.body).to include('Nightly backup')
    expect(response.body).not_to include('Crawl docs')
  end

  it 'sends a query along when it turns a frame request into a page' do
    get "/s/#{space.uuid}/tasks", params: { q: 'backup' }

    expect(response).to redirect_to(space_path(space.uuid, q: 'backup'))
  end
end
