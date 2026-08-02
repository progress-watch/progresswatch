# frozen_string_literal: true

Rails.application.routes.draw do
  # Web UI.
  root 'pages#index'

  resources :spaces, only: %i[create show update], param: :uuid, path: 's',
                     controller: 'dashboards', as: :dashboards do
    # The turbo-frame the dashboard re-fetches every couple of seconds.
    get :tasks, on: :member
  end

  get 'connect/:section', to: 'pages#connect', as: :connect,
                          constraints: { section: /cli|mcp|agent|docker|curl/ }

  # JSON API. The whole surface — resist adding to it. Pinned to JSON so a browser
  # hitting these paths cannot negotiate its way into an HTML response the CLI and
  # the mobile app would then have to cope with.
  defaults format: :json do
    # No `update` here on purpose. Renaming exists because a browser has to create a
    # space before anyone can name it; a CLI or an agent already knows the name and the
    # icon at creation time, so the endpoint would be surface with no caller.
    resources :spaces, only: %i[create show], param: :uuid do
      resources :tasks, only: %i[create]
    end

    # `update` here answers PATCH as well as PUT. TasksController turns PATCH away,
    # because a write replaces the entire volatile state and PATCH promises a merge.
    resources :tasks, only: %i[show update], param: :uuid

    # MCP over Streamable HTTP. One endpoint answering POST and GET, with the space
    # either in the path or in an X-Space-Uuid header.
    post 'mcp(/:space_uuid)', to: 'mcp#create', as: :mcp
    get 'mcp(/:space_uuid)', to: 'mcp#show'
  end

  get 'up', to: 'health#show'
end
