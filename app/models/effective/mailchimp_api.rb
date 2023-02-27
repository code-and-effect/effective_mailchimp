# The Mailchimp API object
# https://github.com/mailchimp/mailchimp-marketing-ruby
# https://mailchimp.com/developer/marketing/api/

require 'MailchimpMarketing'

module Effective
  class MailchimpApi
    attr_accessor :client

    def initialize(api_key:, server:)
      @client = ::MailchimpMarketing::Client.new()
      @client.set_config(api_key: api_key, server: server)
    end

    def ping
      client.ping.get()
    end

    def lists
      client.lists.get_all_lists()
    end

  end
end
