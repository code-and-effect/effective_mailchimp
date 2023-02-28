require 'effective_resources'
require 'effective_datatables'
require 'effective_mailchimp/engine'
require 'effective_mailchimp/version'

module EffectiveMailchimp

  def self.config_keys
    [
      :mailchimp_lists_table_name, :mailchimp_list_members_table_name,
      :layout,
      :mailer, :parent_mailer, :deliver_method, :mailer_layout, :mailer_sender, :mailer_admin, :mailer_subject, :use_effective_email_templates,
      :api_key, :server
    ]
  end

  include EffectiveGem

  def self.api
    Effective::MailchimpApi.new(api_key: api_key, server: server)
  end

  def self.permitted_params
    [ :mailchimp_user_form_action, mailchimp_list_members_attributes: [:id, :subscribed] ]
  end

end
