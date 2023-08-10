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

    def admin_url
      "https://#{server}.admin.mailchimp.com"
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
      Rails.logger.info "[effective_mailchimp] Index Lists..." if debug?

      response = client.lists.get_all_lists(count: 250)
      Array(response['lists']) - [nil, '', {}]
    end

    def list(id)
      Rails.logger.info "[effective_mailchimp] Show List..." if debug?

      client.lists.get_list(id.try(:mailchimp_id) || id)
    end

    def list_member(id, email)
      raise('expected an email') unless email.to_s.include?('@')

      begin
        client.lists.get_list_member(id.try(:mailchimp_id) || id, email)
      rescue MailchimpMarketing::ApiError => e
        {}
      end
    end

    def list_merge_fields(id)
      response = client.lists.get_list_merge_fields(id, count: 100)
      Array(response['merge_fields']) - [nil, '', {}]
    end

    def add_merge_field(id, name:, type: :text)
      raise("invalid mailchimp merge key: #{name}. Must be 10 or fewer characters") if name.to_s.length > 10

      payload = { name: name.to_s.titleize, tag: name.to_s, type: type }

      begin
        client.lists.add_list_merge_field(id, payload)
      rescue MailchimpMarketing::ApiError => e
        false
      end
    end

    def list_member_add(member)
      raise('expected an Effective::MailchimpListMember') unless member.kind_of?(Effective::MailchimpListMember)

      existing = list_member(member.mailchimp_list, member.user.email)
      return existing if existing.present?

      merge_fields = member.user.mailchimp_merge_fields
      raise('expected user mailchimp_merge_fields to be a Hash') unless merge_fields.kind_of?(Hash)

      payload = {
        email_address: member.user.email,
        status: (member.subscribed ? 'subscribed' : 'unsubscribed'),
        merge_fields: merge_fields.delete_if { |k, v| v.blank? }
      }

      begin
        client.lists.add_list_member(member.mailchimp_list.mailchimp_id, payload)
      rescue MailchimpMarketing::ApiError => e
        return false if e.status == 400 && e.to_s.downcase.include?("member in compliance state")
        raise(e)
      end

    end

    def list_member_update(member)
      raise('expected an Effective::MailchimpListMember') unless member.kind_of?(Effective::MailchimpListMember)

      merge_fields = member.user.mailchimp_merge_fields
      raise('expected user mailchimp_merge_fields to be a Hash') unless merge_fields.kind_of?(Hash)

      payload = {
        email_address: member.user.email,
        status: (member.subscribed ? 'subscribed' : 'unsubscribed'),
        merge_fields: merge_fields.delete_if { |k, v| v.blank? }
      }

      client.lists.update_list_member(member.mailchimp_list.mailchimp_id, member.email, payload)
    end

  end
end
