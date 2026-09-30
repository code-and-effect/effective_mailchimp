# The Mailchimp API object
# https://github.com/mailchimp/mailchimp-marketing-ruby
# https://mailchimp.com/developer/marketing/api/

require 'MailchimpMarketing'
require 'digest'

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
        client.lists.get_list_member(id.try(:mailchimp_id) || id, subscriber_hash(email))
      rescue MailchimpMarketing::ApiError => e
        raise unless e.status == 404
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

    def list_member_add(member, preserve_status: false)
      raise('expected an Effective::MailchimpListMember') unless member.kind_of?(Effective::MailchimpListMember)

      Rails.logger.info "[effective_mailchimp] Add List Member" if debug?
      return if sandbox_mode?

      # Actually add or update
      payload = list_member_payload(member).merge(status_if_new: (member.subscribed? ? 'subscribed' : 'unsubscribed'))
      payload = payload.except(:status) if preserve_status
      list_id = member.mailchimp_list.mailchimp_id
      hash = subscriber_hash(member.user.email)

      begin
        client.lists.set_list_member(list_id, hash, payload)
      rescue MailchimpMarketing::ApiError => e
        raise unless self.class.member_exists_error?(e)

        client.lists.update_list_member(list_id, hash, payload.except(:status_if_new))
      end
    end

    def list_member_update(member)
      raise('expected an Effective::MailchimpListMember') unless member.kind_of?(Effective::MailchimpListMember)

      Rails.logger.info "[effective_mailchimp] Update List Member" if debug?
      return if sandbox_mode?

      payload = list_member_payload(member)
      hash = member.mailchimp_id.presence || subscriber_hash(member.email)
      client.lists.update_list_member(member.mailchimp_list.mailchimp_id, hash, payload)
    rescue MailchimpMarketing::ApiError => e
      raise unless self.class.cleaned_member_error?(e) && hash != subscriber_hash(member.user.email)

      # Cleaned addresses cannot be edited. Reuse or add the corrected address instead.
      list_member(member.mailchimp_list, member.user.email).presence || list_member_add(member, preserve_status: true)
    end

    def self.error_body(error)
      # The SDK stores the response body without exposing a reader.
      body = JSON.parse(error.instance_variable_get(:@response_body).to_s)
      body.kind_of?(Hash) ? body : {}
    rescue JSON::ParserError
      {}
    end

    def self.member_exists_error?(error)
      error.status == 400 && error_body(error)['title'].to_s.casecmp?('Member Exists')
    end

    def self.compliance_error?(error)
      error.status == 400 && error_body(error)['title'].to_s.casecmp?('Member In Compliance State')
    end

    def self.cleaned_member_error?(error)
      return false unless error.status == 400

      fields = error_body(error)['errors']
      fields.kind_of?(Array) && fields.present? && fields.all? do |field|
        field.kind_of?(Hash) && field['field'] == 'email address' &&
          field['message'].to_s.match?(/\bcleaned\b/i)
      end
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

    def subscriber_hash(email)
      raise('expected an email') unless email.to_s.include?('@')

      Digest::MD5.hexdigest(email.to_s.strip.downcase)
    end

  end
end
