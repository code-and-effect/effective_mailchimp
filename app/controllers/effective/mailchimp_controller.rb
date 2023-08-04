module Effective
  class MailchimpController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)

    def mailchimp_sync_user
      resource = current_user

      EffectiveResources.authorize!(self, :mailchimp_sync_user, current_user)

      resource.mailchimp_sync!

      flash[:success] = "Successfully synced mailchimp"

      redirect_back(fallback_location: '/settings')
    end

  end
end
