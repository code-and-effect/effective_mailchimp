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

  def cleaned_error(status: 400)
    MailchimpMarketing::ApiError.new(status: status, response_body: {
      title: 'Invalid Resource', errors: [{ field: 'email address', message:
        %(This member's status is "cleaned." You can only update email addresses for members with a status of "subscribed.") }]
    }.to_json)
  end

  test 'cleaned refusal for an unchanged email does not create another contact' do
    m = member(stored_email: 'mixed.case@example.com', mailchimp_id: Digest::MD5.hexdigest('mixed.case@example.com'))
    error = cleaned_error
    lists = Object.new
    lists.define_singleton_method(:update_list_member) { |*| raise error }

    assert_same error, assert_raises(MailchimpMarketing::ApiError) { api_with(lists).list_member_update(m) }
  end

  test 'corrected cleaned addresses are upserted separately with status only for new contacts' do
    [true, false].each do |subscribed|
      old_hash = Digest::MD5.hexdigest('old@example.com')
      new_hash = Digest::MD5.hexdigest('new@example.com')
      m = member(email: 'new@example.com', stored_email: 'old@example.com', mailchimp_id: old_hash)
      m.subscribed = subscribed
      error = cleaned_error
      calls = []
      lists = Object.new
      lists.define_singleton_method(:update_list_member) do |list_id, hash, body|
        calls << [:patch, list_id, hash]
        raise error
      end
      lists.define_singleton_method(:get_list_member) do |list_id, hash|
        calls << [:get, list_id, hash]
        raise MailchimpMarketing::ApiError.new(status: 404)
      end
      lists.define_singleton_method(:set_list_member) do |list_id, hash, body|
        calls << [:put, list_id, hash, body]
        { 'id' => hash, 'email_address' => body[:email_address], 'status' => body[:status_if_new] }
      end

      result = api_with(lists).list_member_update(m)

      assert_equal new_hash, result['id']
      assert_equal (subscribed ? 'subscribed' : 'unsubscribed'), result['status']
      assert_equal [[:patch, 'audience', old_hash], [:get, 'audience', new_hash]], calls.first(2)
      assert_equal [:put, 'audience', new_hash], calls.last.first(3)
      assert_equal({ email_address: 'new@example.com', merge_fields: { FNAME: 'Jane' },
                     status_if_new: (subscribed ? 'subscribed' : 'unsubscribed') }, calls.last.last)
    end
  end

  test 'corrected emails reuse existing contacts without changing their subscription state' do
    %w[subscribed unsubscribed cleaned pending].each do |status|
      old_hash = Digest::MD5.hexdigest('old@example.com')
      new_hash = Digest::MD5.hexdigest('new@example.com')
      m = member(email: 'new@example.com', stored_email: 'old@example.com', mailchimp_id: old_hash)
      error = cleaned_error
      existing = { 'id' => new_hash, 'email_address' => 'new@example.com', 'status' => status }
      calls = []
      lists = Object.new
      lists.define_singleton_method(:update_list_member) do |list_id, hash, body|
        calls << [:patch, list_id, hash]
        raise error
      end
      lists.define_singleton_method(:get_list_member) do |list_id, hash|
        calls << [:get, list_id, hash]
        existing
      end

      assert_same existing, api_with(lists).list_member_update(m)
      assert_equal [[:patch, 'audience', old_hash], [:get, 'audience', new_hash]], calls
    end
  end

  test 'Member Exists retry during corrected email upsert preserves existing opt out' do
    calls = []
    hash = Digest::MD5.hexdigest('mixed.case@example.com')
    lists = Object.new
    lists.define_singleton_method(:set_list_member) do |list_id, subscriber_hash, body|
      calls << body
      raise MailchimpMarketing::ApiError.new(status: 400, response_body: '{"title":"Member Exists"}')
    end
    lists.define_singleton_method(:update_list_member) do |list_id, subscriber_hash, body|
      calls << body
      { 'id' => subscriber_hash, 'status' => 'unsubscribed' }
    end

    result = api_with(lists).list_member_add(member, preserve_status: true)

    assert_equal hash, result['id']
    assert_equal 'unsubscribed', result['status']
    assert_equal 'subscribed', calls.first[:status_if_new]
    assert_not calls.first.key?(:status)
    assert_not calls.last.key?(:status)
    assert_not calls.last.key?(:status_if_new)
  end

  test 'recovery lookup and creation failures reach the caller' do
    %i[get_list_member set_list_member].each do |failing_method|
      m = member(email: 'new@example.com', stored_email: 'old@example.com', mailchimp_id: Digest::MD5.hexdigest('old@example.com'))
      error = cleaned_error
      recovery_error = MailchimpMarketing::ApiError.new(status: 500, response_body: '{"title":"Service unavailable"}')
      lists = Object.new
      lists.define_singleton_method(:update_list_member) { |*| raise error }
      lists.define_singleton_method(:get_list_member) { |*| raise MailchimpMarketing::ApiError.new(status: 404) }
      lists.define_singleton_method(failing_method) { |*| raise recovery_error }

      assert_same recovery_error, assert_raises(MailchimpMarketing::ApiError) { api_with(lists).list_member_update(m) }
    end
  end

  test 'only 400 email field errors identifying cleaned contacts are recognized' do
    assert Effective::MailchimpApi.cleaned_member_error?(cleaned_error)
    assert_not Effective::MailchimpApi.cleaned_member_error?(cleaned_error(status: 500))

    body = JSON.parse(cleaned_error.instance_variable_get(:@response_body))
    body['errors'] << { 'field' => 'merge_fields', 'message' => 'A required field is missing' }
    mixed_error = MailchimpMarketing::ApiError.new(status: 400, response_body: body.to_json)
    assert_not Effective::MailchimpApi.cleaned_member_error?(mixed_error)

    ['not JSON', 'null', '[]', '{"errors":["cleaned"]}',
     '{"errors":[{"field":"email address","message":"The uncleaned address is invalid"}]}',
     '{"errors":[{"field":"merge_fields","message":"The value must be cleaned"}]}',
     '{"errors":[]}', '{"errors":[{"field":"email address"}]}'].each do |body|
      error = MailchimpMarketing::ApiError.new(status: 400, response_body: body)
      assert_not Effective::MailchimpApi.cleaned_member_error?(error), body
    end
  end

  test 'cleaned refusal recognition tolerates shorter wording capitalization and punctuation' do
    ['Cleaned', 'Member status: CLEANED', 'This address has been cleaned.',
     %(This member's status is "cleaned.")].each do |message|
      error = MailchimpMarketing::ApiError.new(status: 400, response_body: {
        errors: [{ field: 'email address', message: message }]
      }.to_json)

      assert Effective::MailchimpApi.cleaned_member_error?(error), message
    end
  end

  test 'member exists and compliance checks use the structured title and HTTP status' do
    { 'Member Exists' => :member_exists_error?, 'Member In Compliance State' => :compliance_error? }.each do |title, predicate|
      error = MailchimpMarketing::ApiError.new(status: 400, response_body: { title: title.downcase }.to_json)
      assert Effective::MailchimpApi.public_send(predicate, error)

      [401, 500].each do |status|
        error = MailchimpMarketing::ApiError.new(status: status, response_body: { title: title }.to_json)
        assert_not Effective::MailchimpApi.public_send(predicate, error)
      end

      ['not JSON', 'null', '[]', { title: 'Invalid Resource', detail: title }.to_json].each do |body|
        error = MailchimpMarketing::ApiError.new(status: 400, response_body: body)
        assert_not Effective::MailchimpApi.public_send(predicate, error)
      end
    end
  end
end
