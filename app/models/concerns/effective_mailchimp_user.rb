# EffectiveMailchimpUser
#
# Mark your user model with effective_mailchimp_user to get a few helpers
# And user specific point required scores

module EffectiveMailchimpUser
  extend ActiveSupport::Concern

  module Base
    def effective_mailchimp_user
      include ::EffectiveMailchimpUser
    end
  end

  module ClassMethods
    def effective_mailchimp_user?; true; end
  end

  included do
    has_many :mailchimp_list_members, -> { order(:id) }, as: :user, inverse_of: :user, dependent: :destroy
    accepts_nested_attributes_for :mailchimp_list_members, allow_destroy: true
  end

  def mailchimp_list_member(mailchimp_list:)
    raise('expected a MailchimpList') unless mailchimp_list.kind_of?(Effective::MailchimpList)
    mailchimp_list_members.find { |mlm| mlm.mailchimp_list_id == mailchimp_list.id }
  end

  # Find or build
  def build_mailchimp_list_member(mailchimp_list:)
    raise('expected a MailchimpList') unless mailchimp_list.kind_of?(Effective::MailchimpList)
    mailchimp_list_member(mailchimp_list: mailchimp_list) || mailchimp_list_members.build(mailchimp_list: mailchimp_list)
  end

end
