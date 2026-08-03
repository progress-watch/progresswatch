# frozen_string_literal: true

Rails.application.routes.draw do
  # Web UI. One purpose per controller, docuseal's convention: anything that is not a
  # REST action on a resource gets its own controller rather than becoming a custom
  # action on someone else's.
  root 'home#show'

  get 'docs', to: 'docs#index'

  resources :spaces, only: %i[show new create edit update], param: :uuid, path: 's'

  get 's/:uuid/tasks', to: 'space_tasks#index', as: :space_tasks

  # Web-only, for the same reason renaming is: only a browser has a push endpoint.
  post 's/:uuid/push', to: 'space_push_subscriptions#create', as: :space_push
  delete 's/:uuid/push', to: 'space_push_subscriptions#destroy'

  # No route constraint on :section — an unknown one is a page that does not exist,
  # and that is the not-found page rather than a bare routing error.
  get 'docs/:section', to: 'docs#show', as: :docs_section

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

  get 'up', to: 'health#show'
end
