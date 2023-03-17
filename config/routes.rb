# frozen_string_literal: true

Rails.application.routes.draw do
  mount EffectiveMailchimp::Engine => '/', as: 'effective_mailchimp'
end

EffectiveMailchimp::Engine.routes.draw do
  # Public routes
  scope module: 'effective' do
  end

  namespace :admin do
    resources :mailchimp_lists, only: [:index, :edit, :update] do
      post :can_subscribe, on: :member
      post :cannot_subscribe, on: :member

      post :force_subscribe, on: :member
      post :unforce_subscribe, on: :member
    end

    resources :mailchimp, only: [] do
      post :mailchimp_sync_user, on: :member
    end

  end

end
