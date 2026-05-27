require 'test_helper'

class MailchimpApiTest < ActiveSupport::TestCase
  def api
    @api ||= Effective::MailchimpApi.new(api_key: 'test-us1')
  end

  test 'subscriber_hash is the md5 of the lowercase email' do
    expected = Digest::MD5.hexdigest('brenda.barrera@quadreal.com')

    assert_equal expected, api.subscriber_hash('brenda.barrera@quadreal.com')
  end

  test 'subscriber_hash lowercases and strips before hashing' do
    expected = Digest::MD5.hexdigest('brenda.barrera@quadreal.com')

    assert_equal expected, api.subscriber_hash('  Brenda.Barrera@QuadReal.com  ')
  end

  test 'subscriber_hash raises without an email' do
    assert_raises(RuntimeError) { api.subscriber_hash('not-an-email') }
  end

end
