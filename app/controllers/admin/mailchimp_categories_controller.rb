module Admin
  class MailchimpCategoriesController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)
    before_action { EffectiveResources.authorize!(self, :admin, :effective_mailchimp) }

    include Effective::CrudController

    private

    def permitted_params
      params.require(:effective_mailchimp_category).permit!
    end

  end
end
