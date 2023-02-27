# frozen_string_literal: true

Rails.application.routes.draw do
  mount EffectiveMailchimp::Engine => '/', as: 'effective_mailchimp'
end

EffectiveMailchimp::Engine.routes.draw do
  # Public routes
  scope module: 'effective' do
  end

  namespace :admin do
  end

end
