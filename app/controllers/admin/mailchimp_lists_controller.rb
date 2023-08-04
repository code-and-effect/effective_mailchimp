module Admin
  class MailchimpListsController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)
    before_action { EffectiveResources.authorize!(self, :admin, :effective_mailchimp) }

    include Effective::CrudController

    def mailchimp_sync
      EffectiveResources.authorize!(self, :mailchimp_sync, Effective::MailchimpList)

      Effective::MailchimpList.sync!

      flash[:success] = "Successfully synced mailchimp lists"

      redirect_back(fallback_location: effective_mailchimp.admin_mailchimp_lists_path)
    end

    private

    def permitted_params
      params.require(:effective_mailchimp_list).permit!
    end

  end
end
