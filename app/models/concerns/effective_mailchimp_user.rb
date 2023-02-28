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
    attr_accessor :mailchimp_user_form_action

    has_many :mailchimp_list_members, -> { Effective::MailchimpListMember.order(:id) }, as: :user, class_name: 'Effective::MailchimpListMember', dependent: :destroy
    accepts_nested_attributes_for :mailchimp_list_members, allow_destroy: true

    has_many :mailchimp_lists, through: :mailchimp_list_members, class_name: 'Effective::MailchimpList'
    accepts_nested_attributes_for :mailchimp_lists, allow_destroy: true

    # The user updated the form
    after_commit(on: :save, if: -> { mailchimp_user_form_action.present? }) do
    end

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

  # Pulls the current status from Mailchimp API into the Mailchimp List Member objects
  def mailchimp_sync!
    Effective::MailchimpListMember.sync!(user: self)
  end

  # Sends the Mailchimp List Member objects to Mailchimp
  def mailchimp_update!
  end

end
