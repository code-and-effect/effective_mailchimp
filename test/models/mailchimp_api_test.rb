require 'test_helper'

class MailchimpApiTest < ActiveSupport::TestCase
  def api_with(lists)
    Effective::MailchimpApi.new(api_key: 'test-us1').tap do |api|
      api.client = Struct.new(:lists).new(lists)
    end
  end

  def member(email: 'Mixed.Case@Example.com', stored_email: nil, mailchimp_id: nil)
    user = User.new(email: email)
    user.define_singleton_method(:mailchimp_merge_fields) { { FNAME: 'Jane' } }
    list = Effective::MailchimpList.new(mailchimp_id: 'audience')

    Effective::MailchimpListMember.new(
      user: user, mailchimp_list: list, subscribed: true,
      email_address: stored_email, mailchimp_id: mailchimp_id
    )
  end

  test 'member lookup uses the documented subscriber hash and only treats 404 as absent' do
    hash = Digest::MD5.hexdigest('mixed.case@example.com')
    calls = []
    lists = Object.new
    lists.define_singleton_method(:get_list_member) do |list_id, subscriber_hash|
      calls << [list_id, subscriber_hash]
      { 'status' => 'subscribed' }
    end

    assert_equal 'subscribed', api_with(lists).list_member('audience', ' Mixed.Case@Example.com ')['status']
    assert_equal [['audience', hash]], calls

    [404, 401, 500].each do |status|
      error = MailchimpMarketing::ApiError.new(status: status)
      failing_lists = Object.new
      failing_lists.define_singleton_method(:get_list_member) { |*, **| raise error }

      if status == 404
        assert_equal({}, api_with(failing_lists).list_member('audience', 'person@example.com'))
      else
        assert_raises(MailchimpMarketing::ApiError) { api_with(failing_lists).list_member('audience', 'person@example.com') }
      end
    end
  end

  test 'new member upsert uses the subscriber hash and status_if_new' do
    hash = Digest::MD5.hexdigest('mixed.case@example.com')
    payload = { email_address: 'Mixed.Case@Example.com', status: 'subscribed',
                merge_fields: { FNAME: 'Jane' }, status_if_new: 'subscribed' }
    calls = []
    lists = Object.new
    lists.define_singleton_method(:set_list_member) do |list_id, subscriber_hash, body|
      calls << [list_id, subscriber_hash, body]
      { 'id' => hash }
    end

    assert_equal hash, api_with(lists).list_member_add(member)['id']
    assert_equal [['audience', hash, payload]], calls
  end

  test 'Member Exists on upsert applies the requested update' do
    hash = Digest::MD5.hexdigest('mixed.case@example.com')
    payload = { email_address: 'Mixed.Case@Example.com', status: 'subscribed',
                merge_fields: { FNAME: 'Jane' } }
    calls = []
    lists = Object.new
    lists.define_singleton_method(:set_list_member) do |list_id, subscriber_hash, body|
      calls << [:put, list_id, subscriber_hash, body]
      raise MailchimpMarketing::ApiError.new(status: 400, response_body: '{"title":"Member Exists"}')
    end
    lists.define_singleton_method(:update_list_member) do |list_id, subscriber_hash, body|
      calls << [:patch, list_id, subscriber_hash, body]
      { 'id' => hash }
    end

    assert_equal hash, api_with(lists).list_member_add(member)['id']
    assert_equal [:put, :patch], calls.map(&:first)
    assert_equal ['audience', hash, payload], calls.last.drop(1)
  end

  test 'compliance refusal on the Member Exists retry reaches the caller' do
    lists = Object.new
    lists.define_singleton_method(:set_list_member) do |*|
      raise MailchimpMarketing::ApiError.new(status: 400, response_body: '{"title":"Member Exists"}')
    end
    lists.define_singleton_method(:update_list_member) do |*|
      raise MailchimpMarketing::ApiError.new(status: 400, response_body: '{"title":"Member In Compliance State"}')
    end

    error = assert_raises(MailchimpMarketing::ApiError) { api_with(lists).list_member_add(member) }
    assert_includes error.to_s, 'Member In Compliance State'
  end

  test 'updates target the stored member id when the email changes' do
    existing_hash = Digest::MD5.hexdigest('old@example.com')
    m = member(email: 'new@example.com', stored_email: 'old@example.com', mailchimp_id: existing_hash)
    payload = { email_address: 'new@example.com', status: 'subscribed', merge_fields: { FNAME: 'Jane' } }
    calls = []
    lists = Object.new
    lists.define_singleton_method(:update_list_member) do |list_id, subscriber_hash, body|
      calls << [list_id, subscriber_hash, body]
      { 'id' => existing_hash }
    end

    assert_equal existing_hash, api_with(lists).list_member_update(m)['id']
    assert_equal [['audience', existing_hash, payload]], calls
  end
end
