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

    has_many :mailchimp_list_members, -> { Effective::MailchimpListMember.sorted }, as: :user, class_name: 'Effective::MailchimpListMember', dependent: :destroy
    accepts_nested_attributes_for :mailchimp_list_members, allow_destroy: true

    has_many :mailchimp_lists, -> { Effective::MailchimpList.sorted }, through: :mailchimp_list_members, class_name: 'Effective::MailchimpList'
    accepts_nested_attributes_for :mailchimp_lists, allow_destroy: true

    # The user updated the form
    after_commit(if: -> { mailchimp_user_form_action }) { mailchimp_update!(force: false) }
  end

  # Intended for app to extend
  def mailchimp_merge_fields
    default_mailchimp_merge_fields()
  end

  # These are the fields we push to Mailchimp on list_add and list_update
  def default_mailchimp_merge_fields
    atts = {}

    if respond_to?(:first_name) && respond_to?(:last_name)
      atts.merge!(
        'FNAME': first_name,
        'LNAME': last_name
      )
    end

    if respond_to?(:addresses)
      address = try(:billing_address) || addresses.last

      atts.merge!(
        'ADDRESS1': address&.address1,
        'ADDRESS2': address&.address2,
        'CITY': address&.city,
        'PROVINCE': address&.province,
        'COUNTRY': address&.country,
        'POSTAL_CODE': address&.postal_code
      )
    end

    if respond_to?(:membership)
      atts.merge!(
        'CATEGORY': membership&.categories&.to_sentence,
        'STATUS': membership&.statuses&.to_sentence,
        'NUMBER': membership&.number,
        'JOINED': membership&.joined_on&.strftime('%F')
      )
    end

    atts
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
    lists = Effective::MailchimpList.subscribable.sorted.to_a

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
      if member.mailchimp_id.blank? && member.subscribed?
        list_member = api.list_member_add(member)
        member.assign_mailchimp_attributes(list_member)
      elsif member.mailchimp_id.present? && (force || mailchimp_member_update_required?(member))
        list_member = api.list_member_update(member)
        member.assign_mailchimp_attributes(list_member)
      end
    end

    save! if mailchimp_list_members_changed?
    true
  end

  def mailchimp_member_update_required?(member)
    require_update = ['email', 'last_name', 'first_name']

    return true if (changes.keys & require_update).present?
    return true if (previous_changes.keys & require_update).present?

    return true if member.changes.present?
    return true if member.previous_changes.present?

    false
  end

end
