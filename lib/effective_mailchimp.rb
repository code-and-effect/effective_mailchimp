require 'effective_resources'
require 'effective_datatables'
require 'effective_mailchimp/engine'
require 'effective_mailchimp/version'

module EffectiveMailchimp

  def self.config_keys
    [
      :mailchimp_lists_table_name, :mailchimp_list_members_table_name,
      :layout,
      :api_key
    ]
  end

  include EffectiveGem

  def self.api
    Effective::MailchimpApi.new(api_key: api_key)
  end

  def self.api_present?
    api_key.present?
  end

  def self.permitted_params
    [ :mailchimp_user_form_action, mailchimp_list_members_attributes: [:id, :subscribed] ]
  end

end
