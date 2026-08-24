# frozen_string_literal: true

Rails.application.routes.draw do
  # Web UI. One purpose per controller, docuseal's convention: anything that is not a
  # REST action on a resource gets its own controller rather than becoming a custom
  # action on someone else's.
  root 'home#show'

  # The suffix form of the root, for a client that can build a URL and not a header:
  # `/.md` is not a path, so this is the only spelling available. `format: true` makes the
  # extension required — a bare constraint lets a missing format through, and `/index`
  # would become a second URL for the dispatcher.
  get 'index', to: 'home#show', format: true, constraints: { format: 'md' }

  # Pinned to HTML the way the API below is pinned to JSON, and for the same reason: these
  # pages have one representation, and a client asking for another reaches a template lookup
  # with nothing to find — 406 from an implicit render, and a raise from an action that
  # renders with an explicit `layout:`. `format: false` closes the other half, so a `.md`
  # somebody appended to a space URL is a path that does not route rather than a format the
  # page cannot serve. Only the root and the docs negotiate.
  scope defaults: { format: :html }, format: false do
    resources :spaces, only: %i[show new create edit update], param: :uuid, path: 's'

    get 's/:uuid/tasks', to: 'space_tasks#index', as: :space_tasks

    # The share modal: the same link as a QR, a URL and a uuid. A route rather than markup
    # on the page, like every other modal here.
    get 's/:uuid/link', to: 'space_links#show', as: :space_link

    # Web-only, for the same reason renaming is: only a browser has a push endpoint.
    post 's/:uuid/push', to: 'space_push_subscriptions#create', as: :space_push
    delete 's/:uuid/push', to: 'space_push_subscriptions#destroy'
  end

  get 'docs/api', to: 'api_docs#index', as: :api_docs

  scope '(:locale)', constraints: { locale: Regexp.union(Locales::ALTERNATES) } do
    get 'docs', to: 'docs#index'
    get 'docs/:section', to: 'docs#show', as: :docs_section
  end

  # JSON API. The whole surface — resist adding to it. Pinned to JSON so a browser
  # hitting these paths cannot negotiate its way into an HTML response the CLI and
  # the mobile app would then have to cope with.
  #
  # `module: :api` and not `namespace :api`: the controllers live in app/controllers/api
  # so the split is visible on disk, but the paths stay where the CLI, the MCP clients
  # and every published snippet expect them.
  scope module: :api, defaults: { format: :json } do
    # No `update` here on purpose. Renaming exists because a browser has to create a
    # space before anyone can name it; a CLI or an agent already knows the name and the
    # icon at creation time, so the endpoint would be surface with no caller.
    resources :spaces, only: %i[create show], param: :uuid, as: :api_spaces

    # Spelled out rather than nested: `resources ... do resources` would rename the
    # parent key to :api_space_uuid to match the `as:` above, and the controller reads
    # params[:space_uuid].
    post 'spaces/:space_uuid/tasks', to: 'tasks#create', as: :api_space_tasks

    # `update` here answers PATCH as well as PUT. Api::TasksController turns PATCH away,
    # because a write replaces the entire volatile state and PATCH promises a merge.
    resources :tasks, only: %i[show update], param: :uuid

    # A GET that writes, which is a thing to do on purpose and nowhere else. It exists for
    # clients that can fire a URL and nothing else — an uptime pinger, a webhook field in
    # somebody else's product, a device. Its own path, because GET /tasks/:uuid must stay a
    # read: browsers prefetch links and chat apps unfurl them.
    get 'tasks/:uuid/report', to: 'tasks#report', as: :report_task

    # MCP over Streamable HTTP. One endpoint answering POST and GET, with the space
    # either in the path or in an X-Space-Uuid header.
    post 'mcp(/:space_uuid)', to: 'mcp#create', as: :mcp
    get 'mcp(/:space_uuid)', to: 'mcp#show'
  end

  # format: false so the extension is literal path text — with it as a format segment
  # Rails drops it from the generated URL, and robots.txt would advertise /sitemap.
  get 'openapi.json', to: 'open_api#show', as: :openapi, format: false
  get 'openapi.yml', to: 'open_api#show', as: :openapi_yaml, format: false, defaults: { format: :yaml }
  get 'sitemap.xml', to: 'sitemap#show', as: :sitemap, format: false, defaults: { format: :xml }
  get 'robots.txt', to: 'robots#show', as: :robots, format: false
  get 'llms.txt', to: 'llms#show', as: :llms, format: false, defaults: { format: :text }

  get 'up', to: 'health#show'
end
