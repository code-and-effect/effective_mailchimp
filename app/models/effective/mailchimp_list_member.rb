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

    def to_s
      full_name.presence || model_name.human
    end

    scope :deep, -> { includes(:mailchimp_list, :user) }
    scope :sorted, -> { order(:name) }

    # # Creates or builds all the Lists
    # def self.sync!
    #   # All the Lists from Mailchimp
    #   lists = EffectiveMailchimp.api.lists

    #   # Only consider public lists
    #   lists = lists.select { |list| list['visibility'] == 'pub' }

    #   # Get all our existing Effective::MailchimpList records
    #   mailchimp_lists = all()

    #   # Find or create Effective::Mailchimp based on existing lists
    #   lists.each do |list|
    #     mailchimp_id = list['id']
    #     web_id = list['web_id']
    #     name = list['name']

    #     mailchimp_list = mailchimp_lists.find { |ml| ml.mailchimp_id == mailchimp_id } || new()
    #     mailchimp_list.assign_attributes(mailchimp_id: mailchimp_id, web_id: web_id, name: name)
    #     mailchimp_list.save!
    #   end

    #   # Destroy any Effective::Mailchimp resources if they no longer returned by lists
    #   mailchimp_lists.each do |mailchimp_list|
    #     list = lists.find { |list| list['id'] == mailchimp_list.mailchimp_id }
    #     mailchimp_list.destroy! unless list.present?
    #   end

    #   true
    # end

  end
end
