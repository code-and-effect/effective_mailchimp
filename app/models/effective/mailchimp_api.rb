# The Mailchimp API object
# https://github.com/mailchimp/mailchimp-marketing-ruby
# https://mailchimp.com/developer/marketing/api/

require 'MailchimpMarketing'

module Effective
  class MailchimpApi
    attr_accessor :api_key
    attr_accessor :server
    attr_accessor :client

    def initialize(api_key:)
      @api_key = api_key
      @server = api_key.to_s.split('-').last

      raise('expected an api key') unless @api_key.present?
      raise('expected an api key') unless @server.present?

      @client = ::MailchimpMarketing::Client.new()
      @client.set_config(api_key: @api_key, server: @server)
    end

    def debug?
      Rails.env.development?
    end

    def sandbox_mode?
      EffectiveMailchimp.sandbox_mode?
    end

    def admin_url
      "https://#{server}.admin.mailchimp.com"
    end

    def audience_url
      "https://#{server}.admin.mailchimp.com/audience/"
    end

    def groups_url
      "https://#{server}.admin.mailchimp.com/audience/groups/"
    end

    def contacts_url
      "https://#{server}.admin.mailchimp.com/audience/contacts"
    end

    def campaigns_url
      "https://#{server}.admin.mailchimp.com/campaigns/"
    end

    def public_url
      "https://mailchimp.com"
    end

    def ping
      client.ping.get()
    end

    # Returns an Array of Lists, which are each Hash
    # Like this [{ ...}, { ... }]
    def lists
      Rails.logger.info "[effective_mailchimp] Index Lists" if debug?

      response = client.lists.get_all_lists(count: 250)
      Array(response['lists']) - [nil, '', {}]
    end

    def list(id)
      Rails.logger.info "[effective_mailchimp] Get List" if debug?

      client.lists.get_list(id.try(:mailchimp_id) || id)
    end

    def categories(list_id)
      Rails.logger.info "[effective_mailchimp] Index Interest Categories" if debug?

      response = client.lists.get_list_interest_categories(list_id.try(:mailchimp_id) || list_id)
      Array(response['categories']) - [nil, '', {}]
    end

    def interests(list_id, category_id)
      Rails.logger.info "[effective_mailchimp] Index Interest Category Interests" if debug?

      response = client.lists.list_interest_category_interests(list_id, category_id)
      Array(response['interests']) - [nil, '', {}]
    end

    def list_member(id, email)
      raise('expected an email') unless email.to_s.include?('@')

      Rails.logger.info "[effective_mailchimp] Get List Member" if debug?

      begin
        client.lists.get_list_member(id.try(:mailchimp_id) || id, email)
      rescue MailchimpMarketing::ApiError => e
        {}
      end
    end

    def list_merge_fields(id)
      Rails.logger.info "[effective_mailchimp] Get List Merge Fields" if debug?

      response = client.lists.get_list_merge_fields(id.try(:mailchimp_id) || id, count: 100)
      Array(response['merge_fields']) - [nil, '', ' ', {}]
    end

    def add_merge_field(id, name:, type: :text)
      raise("invalid mailchimp merge key: #{name}. Must be 10 or fewer characters") if name.to_s.length > 10

      Rails.logger.info "[effective_mailchimp] Add List Merge Field #{name}" if debug?
      return if sandbox_mode?

      payload = { name: name.to_s.titleize, tag: name.to_s, type: type }

      begin
        client.lists.add_list_merge_field(id.try(:mailchimp_id) || id, payload)
      rescue MailchimpMarketing::ApiError => e
        EffectiveLogger.error(e.message, details: name.to_s) if defined?(EffectiveLogger)
        false
      end
    end

    def list_member_add(member)
      raise('expected an Effective::MailchimpListMember') unless member.kind_of?(Effective::MailchimpListMember)

      Rails.logger.info "[effective_mailchimp] Add List Member" if debug?
      return if sandbox_mode?

      # See if they exist somehow
      existing = list_member(member.mailchimp_list, member.user.email)

      if existing.present?
        member.assign_attributes(mailchimp_id: existing['id'])
        return list_member_update(member)
      end

      # Actually add
      payload = list_member_payload(member)
      client.lists.add_list_member(member.mailchimp_list.mailchimp_id, payload)
    end

    def list_member_update(member)
      raise('expected an Effective::MailchimpListMember') unless member.kind_of?(Effective::MailchimpListMember)

      Rails.logger.info "[effective_mailchimp] Update List Member" if debug?
      return if sandbox_mode?

      payload = list_member_payload(member)
      client.lists.update_list_member(member.mailchimp_list.mailchimp_id, member.email, payload)
    end

    def list_member_payload(member)
      raise('expected an Effective::MailchimpListMember') unless member.kind_of?(Effective::MailchimpListMember)

      merge_fields = member.user.mailchimp_merge_fields
      raise('expected user mailchimp_merge_fields to be a Hash') unless merge_fields.kind_of?(Hash)

      payload = {
        email_address: member.user.email,
        status: (member.subscribed ? 'subscribed' : 'unsubscribed'),
        merge_fields: merge_fields.transform_values { |value| value || '' },
        interests: member.interests_hash.presence
      }.compact
    end

  end
end
