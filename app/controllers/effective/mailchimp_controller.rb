module Effective
  class MailchimpController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)

    def mailchimp_sync_user
      resource = current_user

      EffectiveResources.authorize!(self, :mailchimp_sync_user, current_user)

      api = EffectiveMailchimp.api
      resource.mailchimp_sync!(api: api)
      resource.mailchimp_update!(api: api)

      flash[:success] = "Successfully synced mailchimp"

      redirect_back(fallback_location: '/settings')
    end

  end
end
