module Admin
  class MailchimpListMembersController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)
    before_action { EffectiveResources.authorize!(self, :admin, :effective_mailchimp) }

    include Effective::CrudController

    private

    def permitted_params
      params.require(:effective_mailchimp_list_member).permit!
    end

  end
end
