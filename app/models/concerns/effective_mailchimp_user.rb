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

    def require_mailchimp_update_fields
      ['email', 'last_name', 'first_name']
    end
  end

  included do
    attr_accessor :mailchimp_user_form_action

    has_many :mailchimp_list_members, -> { Effective::MailchimpListMember.sorted }, as: :user, class_name: 'Effective::MailchimpListMember', dependent: :destroy
    accepts_nested_attributes_for :mailchimp_list_members, allow_destroy: true

    has_many :mailchimp_lists, -> { Effective::MailchimpList.sorted }, through: :mailchimp_list_members, class_name: 'Effective::MailchimpList'
    accepts_nested_attributes_for :mailchimp_lists, allow_destroy: true

    scope :deep_effective_mailchimp_user, -> { 
      includes(mailchimp_list_members: [:mailchimp_list])
    }

    # The user updated the form
    after_commit(if: -> { mailchimp_member_update_required? }, unless: -> { EffectiveMailchimp.supressed? || @mailchimp_member_update_enqueued }) do
      @mailchimp_member_update_enqueued = true
      EffectiveMailchimpUpdateJob.perform_later(self) # This calls user.mailchimp_update! on the background
    end
  end

  def mailchimp_subscribed?(mailchimp_list)
    raise('expected a MailchimpList') unless mailchimp_lists.all? { |list| list.kind_of?(Effective::MailchimpList) }

    member = mailchimp_list_member(mailchimp_list: mailchimp_list)
    return false if member.blank?

    member.subscribed? && member.synced?
  end

  # Api method to just subscribe this user to this list right now
  # Pass one list or an Array of lists
  def mailchimp_subscribe!(mailchimp_list, subscribed: true, now: false)
    mailchimp_lists = Array(mailchimp_list)
    raise('expected a MailchimpList') unless mailchimp_lists.all? { |list| list.kind_of?(Effective::MailchimpList) }

    mailchimp_lists.each do |mailchimp_list|
      member = build_mailchimp_list_member(mailchimp_list: mailchimp_list)
      member.assign_attributes(subscribed: subscribed)
    end

    # For use in a rake task. Run the update right now
    if now
      return mailchimp_update!(only: mailchimp_lists)
    end

    # This sets up the after_commit to run the mailchimp_update! job
    assign_attributes(mailchimp_user_form_action: true)
    save!
  end

  # Api method to just unsubscribe this user to this list right now
  # Pass one list or an Array of lists
  def mailchimp_unsubscribe!(mailchimp_list)
    mailchimp_lists = Array(mailchimp_list)
    raise('expected a MailchimpList') unless mailchimp_lists.all? { |list| list.kind_of?(Effective::MailchimpList) }

    mailchimp_lists.each do |mailchimp_list|
      member = build_mailchimp_list_member(mailchimp_list: mailchimp_list)
      member.assign_attributes(subscribed: false)
    end

    # This sets up the after_commit to run the mailchimp_update! job
    assign_attributes(mailchimp_user_form_action: true)

    save!
  end

  # Intended for app to extend
  def mailchimp_merge_fields
    default_mailchimp_merge_fields()
  end

  # These are the fields we push to Mailchimp on list_add and list_update
  # Keys can only be 10 characters long
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
        'POSTALCODE': address&.postal_code
      )
    end

    if respond_to?(:membership)
      membership = memberships.first() # Individual or organization membership

      atts.merge!(
        'CATEGORY': membership&.categories&.to_sentence,
        'STATUS': membership&.statuses&.to_sentence,
        'NUMBER': membership&.number,
        'JOINED': membership&.joined_on&.strftime('%F'),
        'FEESPAIDTO': mailchimp_membership_fees_paid_through_period()&.strftime('%F')
      )
    end

    if self.class.respond_to?(:effective_memberships_organization_user?)
      atts.merge!(
        'COMPANY': representatives.map { |rep| rep.organization.to_s }.join(', ').presence,
        'ROLES': representatives.flat_map { |rep| rep.roles }.compact.join(', ').presence,
      )
    end

    atts
  end

  # Returns the maximum fees_paid_through_period of the membership and any deferred membership_period fees
  def mailchimp_membership_fees_paid_through_period
    periods = []

    # Find the fees_paid_through_period from any membership
    if self.class.respond_to?(:effective_memberships_user?) && memberships.present?
      membership = memberships.first() # Individual or organization membership
      periods << membership&.fees_paid_through_period
    end

    # Find the fees_paid_through_period from any deferred membership fees
    fees = if self.class.respond_to?(:effective_memberships_organization_user?) && organizations.present?
      Effective::Fee.deferred.where(owner: [self, organizations])
    else
      Effective::Fee.deferred.where(owner: self)
    end

    periods += fees.select { |fee| fee.membership_period_fee? }.map(&:fees_paid_through_period)

    # Return the maximum fees paid through period
    periods.compact.max
  end

  def mailchimp_subscribed_lists
    mailchimp_list_members.select(&:subscribed?).map(&:mailchimp_list)
  end

  def mailchimp_subscribed_interests
    mailchimp_list_members.select(&:subscribed?).flat_map(&:interests)
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

  def mailchimp_last_synced_at
    mailchimp_list_members.map(&:last_synced_at).compact.min
  end

  # Used by the form to set it up for all lists
  def build_mailchimp_list_members
    mailchimp_lists = Effective::MailchimpList.subscribable.sorted.to_a

    mailchimp_lists.each do |mailchimp_list|
      build_mailchimp_list_member(mailchimp_list: mailchimp_list)
    end

    mailchimp_list_members
  end

  # Pulls the current status from Mailchimp API into the Mailchimp List Member objects
  # Run before the mailchimp fields are displayed
  # Only run in the background when a user or admin clicks sync now
  def mailchimp_sync!(api: EffectiveMailchimp.api)
    lists = Effective::MailchimpList.subscribable.sorted.to_a

    assign_attributes(mailchimp_user_form_action: nil)

    Timeout::timeout(lists.length * 2) do
      lists.each do |mailchimp_list|
        member = build_mailchimp_list_member(mailchimp_list: mailchimp_list)

        list_member = api.list_member(mailchimp_list, email) || {}
        member.assign_mailchimp_attributes(list_member)
      end
    end

    mailchimp_list_members.each do |member|
      list = lists.find { |list| list.id == member.mailchimp_list_id }
      member.mark_for_destruction unless list.present?
    end

    save!
  end

  # Pushes the current Mailchimp List Member objects to Mailchimp when needed
  # Called in the background after a form submission that changes the user email/last_name/first_name or mailchimp subscriptions
  def mailchimp_update!(api: EffectiveMailchimp.api, only: [], except: [])
    assign_attributes(mailchimp_user_form_action: nil)

    mailchimp_list_members.each do |member|
      next if only.present? && Array(only).exclude?(member.mailchimp_list)
      next if except.present? && Array(except).include?(member.mailchimp_list)

      begin
        list_member = if member.mailchimp_id.blank? && member.subscribed?
          api.list_member_add(member)
        elsif member.mailchimp_id.present?
          api.list_member_update(member)
        end

        member.assign_mailchimp_attributes(list_member) if list_member.present?
      rescue MailchimpMarketing::ApiError => e
        if e.to_s.downcase.include?("cannot be subscribed") || e.to_s.downcase.include?('deleted')
          member.assign_mailchimp_cannot_be_subscribed
        else
          raise(e)
        end
      end
    end

    save!
  end

  private

  def mailchimp_member_update_required?
    return false unless mailchimp_user_form_action
    return false if self.class.respond_to?(:effective_memberships_user) && membership&.mailchimp_membership_update_required?

    # Update if my email first name or last name change
    require_update = self.class.require_mailchimp_update_fields()
    return true if (changes.keys & require_update).present?
    return true if (previous_changes.keys & require_update).present?

    # Update if any of my mailchimp list members changed
    # which happens when I submit a form and change the Mailchimp values
    return true if mailchimp_list_members.any? { |m| m.changes.present? || m.previous_changes.present? || m.marked_for_destruction? }

    false
  end

end
