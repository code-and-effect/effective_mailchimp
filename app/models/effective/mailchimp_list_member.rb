module Effective
  class MailchimpListMember < ActiveRecord::Base
    self.table_name = (EffectiveMailchimp.mailchimp_list_members_table_name || :mailchimp_list_members).to_s

    belongs_to :user, polymorphic: true
    belongs_to :mailchimp_list

    effective_resource do
      mailchimp_id    :string
      web_id          :string

      email_address   :string
      full_name       :string

      subscribed      :boolean

      timestamps
    end

    scope :deep, -> { includes(:mailchimp_list, :user) }
    scope :sorted, -> { order(:name) }

    def to_s
      mailchimp_list&.to_s || model_name.human
    end

    # Creates or builds all the Lists
    def self.sync!(user:)
      raise('expected an effective_mailchimp_user') unless user.class.respond_to?(:effective_mailchimp_user)

      api = EffectiveMailchimp.api
      lists = MailchimpList.subscribable.order(:id)

      lists.find_each do |mailchimp_list|
        mailchimp_list_member = user.build_mailchimp_list_member(mailchimp_list: mailchimp_list)
        list_member = api.list_member(mailchimp_list, user.email) || {}

        mailchimp_list_member.assign_attributes(
          mailchimp_id: list_member['id'],
          web_id: list_member['web_id'],
          email_address: list_member['email'],
          full_name: list_member['full_name'],
          subscribed: (list_member['status'] == 'subscribed')
        )
      end

      user.mailchimp_list_members.each do |member|
        list = lists.find { |list| list.id == member.mailchimp_list_id }
        member.mark_for_destruction unless list.present?
      end

      user.save!
    end

  end
end
