module Effective
  class MailchimpInterest < ActiveRecord::Base
    self.table_name = (EffectiveMailchimp.mailchimp_interests_table_name || :mailchimp_interests).to_s

    belongs_to :mailchimp_list
    belongs_to :mailchimp_category

    effective_resource do
      mailchimp_id      :string     # ID of this interest on Mailchimp

      list_id           :string     # Mailchimp list ID
      category_id       :string     # Interest Category

      name              :string
      list_name         :string
      category_name     :string

      subscriber_count  :integer
      display_order     :integer

      can_subscribe     :boolean
      force_subscribe   :boolean

      timestamps
    end

    validates :mailchimp_id, presence: true
    validates :list_id, presence: true
    validates :category_id, presence: true
    validates :name, presence: true

    scope :deep, -> { all }
    scope :sorted, -> { order(:display_order) }
    scope :subscribable, -> { where(can_subscribe: true) }

    # Creates or builds all the Lists
    def self.sync!(api: EffectiveMailchimp.api)
      # For every mailchimp_list, get all the interests
      mailchimp_lists = Effective::MailchimpList.deep.all

      mailchimp_lists.each do |mailchimp_list|
        mailchimp_list.mailchimp_categories.each do |mailchimp_category|

          # All the Interests from Mailchimp
          interests = api.interests(mailchimp_list.mailchimp_id, mailchimp_category.mailchimp_id)

          # Get all our existing Effective::MailchimpGroup records
          mailchimp_interests = where(mailchimp_list: mailchimp_list, mailchimp_category: mailchimp_category)

          # Find or create Effective::MailchimpInterests based on existing lists and categories 
          interests.each do |interest|
            mailchimp_id = interest['id']
            mailchimp_interest = mailchimp_interests.find { |mi| mi.mailchimp_id == mailchimp_id } || new()

            mailchimp_interest.assign_attributes(
              mailchimp_list: mailchimp_list,
              mailchimp_category: mailchimp_category,

              mailchimp_id: mailchimp_id,

              list_id: interest['list_id'],
              list_name: mailchimp_list.name,

              category_id: interest['category_id'],
              category_name: mailchimp_category.name,

              name: interest['name'],
              display_order: interest['display_order'],
              subscriber_count: interest['subscriber_count']
            )

            mailchimp_interest.assign_attributes(can_subscribe: true) if mailchimp_interest.new_record?
            mailchimp_interest.save!
          end

          # Destroy any Effective::MailchimpGroups resources if they no longer returned by interests
          mailchimp_interests.each do |mailchimp_interest|
            interest = interests.find { |interest| interest['id'] == mailchimp_interest.mailchimp_id }
            mailchimp_interest.destroy! unless interest.present?
          end
        end
      end

      true
    end

    def to_s
      name.presence || model_name.human
    end

  end
end
