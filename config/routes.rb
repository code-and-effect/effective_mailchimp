# frozen_string_literal: true

Rails.application.routes.draw do
  mount EffectiveMailchimp::Engine => '/', as: 'effective_mailchimp'
end

EffectiveMailchimp::Engine.routes.draw do
  # Public routes
  scope module: 'effective' do
    resources :mailchimp, only: [] do
      post :mailchimp_sync_user, on: :member
    end
  end

  namespace :admin do
    resources :mailchimp_lists, only: [:index, :edit, :update]
    resources :mailchimp_interests, only: [:index, :edit, :update]
    resources :mailchimp_categories, only: :index
    resources :mailchimp_list_members, only: :index

    resources :mailchimp, only: [] do
      post :mailchimp_sync, on: :collection
      post :mailchimp_sync_user, on: :member
    end

    get '/mailchimp', to: 'mailchimp#index', as: :mailchimp
  end

end
