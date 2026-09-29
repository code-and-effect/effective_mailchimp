require 'test_helper'
require 'MailchimpMarketing'

class MailchimpUserTest < ActiveSupport::TestCase
  Member = Struct.new(:mailchimp_id, :subscribed, :cannot_be_subscribed) do
    def subscribed?
      subscribed
    end

    def assign_mailchimp_cannot_be_subscribed
      self.subscribed = false
      self.cannot_be_subscribed = true
    end
  end

  def update_with_error(error)
    member = Member.new('existing-id', true, false)
    user = Object.new.extend(EffectiveMailchimpUser)
    user.define_singleton_method(:email) { 'person@example.com' }
    user.define_singleton_method(:id) { 1 }
    user.define_singleton_method(:mailchimp_list_members) { [member] }
    user.define_singleton_method(:save!) { true }

    api = Object.new
    api.define_singleton_method(:list_member_update) { |_| raise error }

    reports = []
    original_send_error = EffectiveResources.method(:send_error)
    EffectiveResources.define_singleton_method(:send_error) { |*args, **kwargs| reports << [args, kwargs] }

    user.mailchimp_update!(api: api)
    [member, reports]
  ensure
    EffectiveResources.define_singleton_method(:send_error, original_send_error) if original_send_error
  end

  test 'handled compliance refusals mark the member unsubscribed without alerting' do
    error = MailchimpMarketing::ApiError.new(
      status: 400,
      response_body: '{"title":"Member In Compliance State"}'
    )

    member, reports = update_with_error(error)

    assert_not member.subscribed?
    assert member.cannot_be_subscribed
    assert_empty reports
  end

  test 'unexpected API errors remain visible' do
    error = MailchimpMarketing::ApiError.new(status: 400, response_body: '{"title":"Invalid Resource"}')

    member, reports = update_with_error(error)

    assert member.subscribed?
    assert_not member.cannot_be_subscribed
    assert_equal 1, reports.length
    assert_same error, reports.first.first.first
  end
end
