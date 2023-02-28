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
    after_commit(if: -> { mailchimp_user_form_action }) { mailchimp_update!(force: false) }
  end

  def mailchimp_subscribed_lists
    mailchimp_list_members.select(&:subscribed?).map(&:mailchimp_list)
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

  def mailchimp_list_members_changed?
    mailchimp_list_members.any? { |mlm| mlm.changes.present? || mlm.marked_for_destruction? }
  end

  def mailchimp_last_synced_at
    mailchimp_list_members.map(&:last_synced_at).min
  end

  def mailchimp_sync_required?
    return true if mailchimp_last_synced_at.blank?
    mailchimp_last_synced_at < (Time.zone.now - 1.day)
  end

  # Pulls the current status from Mailchimp API into the Mailchimp List Member objects
  # Run before the mailchimp fields are displayed
  def mailchimp_sync!(force: true)
    api = EffectiveMailchimp.api
    lists = Effective::MailchimpList.subscribable.order(:id).to_a

    return if lists.length == mailchimp_list_members.length && !(force || mailchimp_sync_required?)

    lists.each do |mailchimp_list|
      member = build_mailchimp_list_member(mailchimp_list: mailchimp_list)

      list_member = api.list_member(mailchimp_list, email) || {}
      member.assign_mailchimp_attributes(list_member)
    end

    mailchimp_list_members.each do |member|
      list = lists.find { |list| list.id == member.mailchimp_list_id }
      member.mark_for_destruction unless list.present?
    end

    save! if mailchimp_list_members_changed?
    true
  end

  # Pushes the current Mailchimp List Member objects to Mailchimp when needed
  def mailchimp_update!(force: true)
    api = EffectiveMailchimp.api

    assign_attributes(mailchimp_user_form_action: nil)

    mailchimp_list_members.map do |member|
      if member.subscribed? && member.mailchimp_id.blank?
        list_member = api.list_member_add(member)
        member.assign_mailchimp_attributes(list_member)
      elsif member.mailchimp_id.present? && (member.previous_changes.present? || force)
        list_member = api.list_member_update(member)
        member.assign_mailchimp_attributes(list_member)
      end
    end

    save! if mailchimp_list_members_changed?
    true
  end

end
