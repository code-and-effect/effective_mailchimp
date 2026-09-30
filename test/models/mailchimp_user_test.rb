require 'test_helper'
require 'MailchimpMarketing'

class MailchimpUserTest < ActiveSupport::TestCase
  def member(email: 'person@example.com', stored_email: 'person@example.com', subscribed: true, blocked: false)
    owner = User.new(email: email)
    owner.define_singleton_method(:mailchimp_merge_fields) { { FNAME: 'Jane' } }

    Effective::MailchimpListMember.new(
      user: owner, mailchimp_list: Effective::MailchimpList.new(mailchimp_id: 'audience'),
      mailchimp_id: Digest::MD5.hexdigest(stored_email.strip.downcase), email_address: stored_email,
      subscribed: subscribed, cannot_be_subscribed: blocked
    )
  end

  def update_user(member, api:)
    user = Object.new.extend(EffectiveMailchimpUser)
    user.define_singleton_method(:email) { member.user.email }
    user.define_singleton_method(:id) { 1 }
    user.define_singleton_method(:mailchimp_list_members) { [member] }
    saves = []
    user.define_singleton_method(:save!) { saves << member.attributes.dup; true }

    reports = []
    original_send_error = EffectiveResources.method(:send_error)
    EffectiveResources.define_singleton_method(:send_error) { |*args, **kwargs| reports << [args, kwargs] }

    user.mailchimp_update!(api: api)
    [reports, saves]
  ensure
    EffectiveResources.define_singleton_method(:send_error, original_send_error) if original_send_error
  end

  def update_with_error(error)
    m = member
    api = Object.new
    api.define_singleton_method(:list_member_update) { |_| raise error }
    reports, = update_user(m, api: api)
    [m, reports]
  end

  def cleaned_error
    MailchimpMarketing::ApiError.new(status: 400, response_body: {
      title: 'Invalid Resource', errors: [{ field: 'email address', message:
        %(This member's status is "cleaned." You can only update email addresses for members with a status of "subscribed.") }]
    }.to_json)
  end

  test 'handled compliance refusals mark the member unsubscribed without alerting' do
    error = MailchimpMarketing::ApiError.new(
      status: 400, response_body: '{"title":"Member In Compliance State"}'
    )

    m, reports = update_with_error(error)

    assert_not m.subscribed?
    assert m.cannot_be_subscribed?
    assert_empty reports
  end

  test 'cleaned refusals save the blocked state without alerting or repeating same address updates' do
    m = member(email: 'Person@Example.com', stored_email: ' person@example.com ')
    error = cleaned_error
    calls = 0
    api = Object.new
    api.define_singleton_method(:list_member_update) { |_| calls += 1; raise error }

    reports, saves = update_user(m, api: api)

    assert_empty reports
    assert_equal false, saves.last['subscribed']
    assert_equal true, saves.last['cannot_be_subscribed']
    assert saves.last['last_synced_at'].present?
    assert_equal ' person@example.com ', saves.last['email_address']

    reports, = update_user(m, api: api)

    assert_empty reports
    assert_equal 1, calls
  end

  test 'same address subscription requests remain unsubscribed when blocked' do
    m = member(subscribed: true, blocked: true)
    m.last_synced_at = 1.day.ago
    synced_at = m.last_synced_at

    reports, saves = update_user(m, api: Object.new)

    assert_empty reports
    assert_equal false, saves.last['subscribed']
    assert_equal true, saves.last['cannot_be_subscribed']
    assert_equal synced_at, saves.last['last_synced_at']
  end

  test 'blocked members can sync again when their email changes' do
    m = member(email: 'new@example.com', stored_email: 'old@example.com', subscribed: false, blocked: true)
    new_hash = Digest::MD5.hexdigest('new@example.com')
    calls = []
    api = Object.new
    api.define_singleton_method(:list_member_update) do |member|
      calls << member
      { 'id' => new_hash, 'email_address' => 'new@example.com', 'status' => 'subscribed' }
    end

    reports, saves = update_user(m, api: api)

    assert_equal [m], calls
    assert_empty reports
    assert_equal new_hash, saves.last['mailchimp_id']
    assert_equal 'new@example.com', saves.last['email_address']
    assert_equal true, saves.last['subscribed']
    assert_equal false, saves.last['cannot_be_subscribed']
  end

  test 'cleaned email recovery saves the new mapping and preserves an existing opt out' do
    %w[subscribed unsubscribed cleaned pending].each do |status|
      m = member(email: 'new@example.com', stored_email: 'old@example.com')
      error = cleaned_error
      new_hash = Digest::MD5.hexdigest('new@example.com')
      lists = Object.new
      lists.define_singleton_method(:update_list_member) { |*| raise error }
      lists.define_singleton_method(:get_list_member) do |*|
        { 'id' => new_hash, 'email_address' => 'new@example.com', 'status' => status }
      end
      api = Effective::MailchimpApi.new(api_key: 'test-us1')
      api.client = Struct.new(:lists).new(lists)

      reports, saves = update_user(m, api: api)

      assert_empty reports
      assert_equal new_hash, saves.last['mailchimp_id']
      assert_equal 'new@example.com', saves.last['email_address']
      assert_equal (status == 'subscribed'), saves.last['subscribed']
      assert_equal %w[unsubscribed cleaned].include?(status), saves.last['cannot_be_subscribed']
    end
  end

  test 'new corrected contact responses update the mapping even when an opt out wins the upsert race' do
    %w[subscribed unsubscribed].each do |status|
      m = member(email: 'new@example.com', stored_email: 'old@example.com')
      error = cleaned_error
      new_hash = Digest::MD5.hexdigest('new@example.com')
      payloads = []
      lists = Object.new
      lists.define_singleton_method(:update_list_member) { |*| raise error }
      lists.define_singleton_method(:get_list_member) { |*| raise MailchimpMarketing::ApiError.new(status: 404) }
      lists.define_singleton_method(:set_list_member) do |list_id, hash, body|
        payloads << body
        { 'id' => hash, 'email_address' => body[:email_address], 'status' => status }
      end
      api = Effective::MailchimpApi.new(api_key: 'test-us1')
      api.client = Struct.new(:lists).new(lists)

      reports, saves = update_user(m, api: api)

      assert_empty reports
      assert_equal new_hash, saves.last['mailchimp_id']
      assert_equal 'new@example.com', saves.last['email_address']
      assert_equal (status == 'subscribed'), saves.last['subscribed']
      assert_equal (status == 'unsubscribed'), saves.last['cannot_be_subscribed']
      assert_equal 'subscribed', payloads.last[:status_if_new]
      assert_not payloads.last.key?(:status)
    end
  end

  test 'unexpected API errors remain visible' do
    error = MailchimpMarketing::ApiError.new(status: 400, response_body: '{"title":"Invalid Resource"}')

    m, reports = update_with_error(error)

    assert m.subscribed?
    assert_not m.cannot_be_subscribed?
    assert_equal 1, reports.length
    assert_same error, reports.first.first.first
  end

  test 'unrelated validation errors containing uncleaned remain visible and do not block the member' do
    error = MailchimpMarketing::ApiError.new(status: 400, response_body: {
      errors: [{ field: 'email address', message: 'The uncleaned address is invalid' }]
    }.to_json)

    m, reports = update_with_error(error)

    assert m.subscribed?
    assert_not m.cannot_be_subscribed?
    assert_equal 1, reports.length
    assert_same error, reports.first.first.first
  end

  test 'unexpected errors while recovering a corrected email remain visible' do
    %i[get_list_member set_list_member].each do |failing_method|
      [400, 401, 500].each do |status|
        m = member(email: 'new@example.com', stored_email: 'old@example.com')
        error = cleaned_error
        recovery_error = MailchimpMarketing::ApiError.new(status: status, response_body: '{"title":"Unexpected failure"}')
        lists = Object.new
        lists.define_singleton_method(:update_list_member) { |*| raise error }
        lists.define_singleton_method(:get_list_member) { |*| raise MailchimpMarketing::ApiError.new(status: 404) }
        lists.define_singleton_method(failing_method) { |*| raise recovery_error }
        api = Effective::MailchimpApi.new(api_key: 'test-us1')
        api.client = Struct.new(:lists).new(lists)

        reports, saves = update_user(m, api: api)

        assert_equal 1, reports.length
        assert_same recovery_error, reports.first.first.first
        assert_equal Digest::MD5.hexdigest('old@example.com'), saves.last['mailchimp_id']
        assert_equal 'old@example.com', saves.last['email_address']
        assert_equal true, saves.last['subscribed']
        assert_equal false, saves.last['cannot_be_subscribed']
      end
    end
  end

  test 'shortened cleaned refusals are handled without alerting' do
    error = MailchimpMarketing::ApiError.new(status: 400, response_body: {
      errors: [{ field: 'email address', message: 'Member status: CLEANED' }]
    }.to_json)

    m, reports = update_with_error(error)

    assert_not m.subscribed?
    assert m.cannot_be_subscribed?
    assert_empty reports
  end

  test 'compliance text in unrelated error details does not suppress the alert' do
    error = MailchimpMarketing::ApiError.new(status: 400, response_body: {
      title: 'Invalid Resource', detail: 'Member In Compliance State is not the cause of this error'
    }.to_json)

    m, reports = update_with_error(error)

    assert m.subscribed?
    assert_not m.cannot_be_subscribed?
    assert_equal 1, reports.length
    assert_same error, reports.first.first.first
  end

  test 'legacy blocked subscription messages are read from structured response details' do
    error = MailchimpMarketing::ApiError.new(status: 400, response_body: {
      title: 'Invalid Resource', detail: 'This member cannot be subscribed'
    }.to_json)

    m, reports = update_with_error(error)

    assert_not m.subscribed?
    assert m.cannot_be_subscribed?
    assert_equal 1, reports.length
    assert_same error, reports.first.first.first
  end
end
