# frozen_string_literal: true

Rails.application.routes.draw do
  root 'home#show'

  get 'index', to: 'home#show', format: true, constraints: { format: 'md' }

  scope defaults: { format: :html }, format: false do
    resources :spaces, only: %i[show new create edit update], param: :uuid, path: 's'

    get 's/:uuid/tasks', to: 'space_tasks#index', as: :space_tasks
    get 's/:uuid/link', to: 'space_links#show', as: :space_link
    post 's/:uuid/push', to: 'space_push_subscriptions#create', as: :space_push
    delete 's/:uuid/push', to: 'space_push_subscriptions#destroy'
  end

  get 'docs/api', to: 'api_docs#index', as: :api_docs

  scope '(:locale)', constraints: { locale: Regexp.union(Locales::ALTERNATES) } do
    get 'docs', to: 'docs#index'
    get 'docs/:section', to: 'docs#show', as: :docs_section
  end

  scope module: :api, defaults: { format: :json } do
    # No update: only a browser creates a space before knowing its name.
    resources :spaces, only: %i[create show], param: :uuid, as: :api_spaces

    post 'spaces/:space_uuid/tasks', to: 'tasks#create', as: :api_space_tasks

    resources :tasks, only: %i[show update], param: :uuid

    get 'tasks/:uuid/report', to: 'tasks#report', as: :report_task
    post 'mcp(/:space_uuid)', to: 'mcp#create', as: :mcp
    get 'mcp(/:space_uuid)', to: 'mcp#show'
  end

  get 'openapi.json', to: 'open_api#show', as: :openapi, format: false
  get 'openapi.yml', to: 'open_api#show', as: :openapi_yaml, format: false, defaults: { format: :yaml }
  get 'sitemap.xml', to: 'sitemap#show', as: :sitemap, format: false, defaults: { format: :xml }
  get 'robots.txt', to: 'robots#show', as: :robots, format: false
  get 'llms.txt', to: 'llms#show', as: :llms, format: false, defaults: { format: :text }

  get 'up', to: 'health#show'
end
