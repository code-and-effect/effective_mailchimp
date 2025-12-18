module Admin
  class MailchimpController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)
    before_action { EffectiveResources.authorize!(self, :admin, :effective_mailchimp) }

    include Effective::CrudController

    page_title 'Mailchimp'

    # /admin/mailchimp
    def index
    end

    # Sync All
    def mailchimp_sync
      EffectiveResources.authorize!(self, :admin, :mailchimp_sync)

      api = EffectiveMailchimp.api
      Effective::MailchimpList.sync!(api: api)
      Effective::MailchimpCategory.sync!(api: api)
      Effective::MailchimpInterest.sync!(api: api)

      flash[:success] = "Successfully synced mailchimp data"

      redirect_back(fallback_location: effective_mailchimp.admin_mailchimp_path)
    end

    # Sync all users
    def mailchimp_sync_users
      EffectiveResources.authorize!(self, :admin, :mailchimp_sync_users)

      user_class_name = current_user.class.name

      # This calls user.mailchimp_sync! on all users
      EffectiveMailchimpSyncUsersJob.perform_later(user_class_name) 

      flash[:success] = "Successfully started mailchimp sync all users background job. Please wait a few minutes for it to complete. Check the logs for progress."

      redirect_back(fallback_location: effective_mailchimp.admin_mailchimp_path)
    end

    # Sync one user
    def mailchimp_sync_user
      resource = current_user.class.find(params[:id])

      EffectiveResources.authorize!(self, :update, resource)

      api = EffectiveMailchimp.api
      resource.mailchimp_sync!
      resource.mailchimp_update!

      flash[:success] = "Successfully synced mailchimp"

      redirect_back(fallback_location: "/admin/users/#{params[:id]}/edit")
    end

  end
end
