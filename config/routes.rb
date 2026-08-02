# frozen_string_literal: true

Rails.application.routes.draw do
  resources :spaces, only: %i[create show], param: :uuid do
    resources :tasks, only: %i[create]
  end

  resources :tasks, only: %i[show update], param: :uuid

  get 'up', to: 'health#show'
end
