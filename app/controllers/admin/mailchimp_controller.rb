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
      merge_fields = current_user.class.new().mailchimp_merge_fields

      Effective::MailchimpList.sync!(api: api, merge_fields: merge_fields)
      Effective::MailchimpCategory.sync!(api: api)
      Effective::MailchimpInterest.sync!(api: api)

      flash[:success] = "Successfully synced mailchimp data"

      redirect_back(fallback_location: effective_mailchimp.admin_mailchimp_path)
    end

    # Sync one user
    def mailchimp_sync_user
      resource = current_user.class.find(params[:id])

      EffectiveResources.authorize!(self, :update, resource)

      resource.mailchimp_sync!

      flash[:success] = "Successfully synced mailchimp"

      redirect_back(fallback_location: "/admin/users/#{params[:id]}/edit")
    end

  end
end
