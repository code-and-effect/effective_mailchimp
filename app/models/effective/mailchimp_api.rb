# The Mailchimp API object
# https://github.com/mailchimp/mailchimp-marketing-ruby
# https://mailchimp.com/developer/marketing/api/

require 'MailchimpMarketing'

module Effective
  class MailchimpApi
    attr_accessor :api_key
    attr_accessor :server
    attr_accessor :client

    def initialize(api_key:, server:)
      raise('expected an api key') unless api_key.present?
      raise('expected a server') unless server.present?

      @api_key = api_key
      @server = server

      @client = ::MailchimpMarketing::Client.new()
      @client.set_config(api_key: api_key, server: server)
    end

    def admin_url
      "https://#{server}.admin.mailchimp.com"
    end

    def ping
      client.ping.get()
    end

    # Returns an Array of Lists, which are each Hash
    # Like this [{ ...}, { ... }]
    def lists
      response = client.lists.get_all_lists()
      Array(response['lists']) - [nil, '', {}]
    end

  end
end
