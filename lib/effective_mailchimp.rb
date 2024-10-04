require 'effective_resources'
require 'effective_datatables'
require 'effective_mailchimp/engine'
require 'effective_mailchimp/version'

module EffectiveMailchimp

  def self.config_keys
    [
      :mailchimp_lists_table_name, :mailchimp_list_members_table_name, :mailchimp_categories_table_name, :mailchimp_interests_table_name,
      :layout,
      :api_key, :sandbox_mode, :user_class_name
    ]
  end

  include EffectiveGem

  def self.api
    Effective::MailchimpApi.new(api_key: api_key)
  end

  def self.sandbox_mode?
    !!sandbox_mode
  end

  def self.api_present?
    api_key.present?
  end

  def self.api_blank?
    api_key.blank?
  end

  def self.lists_present?
    Effective::MailchimpList.all.count > 0
  end

  def self.lists_blank?
    Effective::MailchimpList.all.count == 0
  end

  def self.User
    klass = user_class_name.constantize if user_class_name.present?
    klass ||= Tenant.User if defined?(Tenant)
    klass ||= '::User'.safe_constantize

    raise('unable to determine User klass. Please set config.user_class_name') unless klass.kind_of?(Class)
    raise('expecting an effective_mailchimp_user User class') unless klass.respond_to?(:effective_mailchimp_user)

    klass
  end

  def self.merge_fields
    merge_fields = self.User().new.mailchimp_merge_fields
    raise('expected a Hash of merge fields') unless merge_fields.kind_of?(Hash)
    merge_fields
  end

  def self.permitted_params
    [ :mailchimp_user_form_action, mailchimp_list_members_attributes: [:id, :mailchimp_list_id, :subscribed, interests: []] ]
  end

end
