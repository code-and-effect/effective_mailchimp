module Admin
  class MailchimpController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)
    before_action { EffectiveResources.authorize!(self, :admin, :effective_mailchimp) }

    include Effective::CrudController

    def mailchimp_sync_user
      resource = current_user.class.find(params[:id])

      resource.mailchimp_sync!

      flash[:success] = "Successfully synced mailchimp"

      redirect_back(fallback_location: "/admin/users/#{params[:id]}/edit")
    end

  end
end
