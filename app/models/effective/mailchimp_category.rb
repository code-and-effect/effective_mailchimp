module Effective
  class MailchimpCategory < ActiveRecord::Base
    self.table_name = (EffectiveMailchimp.mailchimp_categories_table_name || :mailchimp_categories).to_s

    belongs_to :mailchimp_list
    has_many :mailchimp_interests

    effective_resource do
      mailchimp_id      :string     # ID of this Mailchimp InterestCategory
      list_id           :string     # Mailchimp list ID

      name              :string     # Title
      list_name         :string

      display_type      :string     # Type

      timestamps
    end

    validates :mailchimp_id, presence: true
    validates :list_id, presence: true
    validates :name, presence: true

    scope :deep, -> { all }
    scope :sorted, -> { order(:name) }
    scope :subscribable, -> { all }

    # Creates or builds all the Lists
    def self.sync!(api: EffectiveMailchimp.api)
      # For every mailchimp_list, get all the categories
      mailchimp_lists = Effective::MailchimpList.all

      mailchimp_lists.each do |mailchimp_list|
        # All the Groups from Mailchimp
        categories = api.categories(mailchimp_list.mailchimp_id)

        # Get all our existing Effective::MailchimpCategory records
        mailchimp_categories = where(mailchimp_list: mailchimp_list)

        # Find or create Effective::MailchimpGroups based on existing groups
        categories.each do |category|
          mailchimp_id = category['id']
          mailchimp_category = mailchimp_categories.find { |mc| mc.mailchimp_id == mailchimp_id } || new()

          mailchimp_category.assign_attributes(
            mailchimp_list: mailchimp_list,

            mailchimp_id: mailchimp_id,
            list_id: category['list_id'],
            list_name: mailchimp_list.name,
            name: (category['title'] || category['name']),
            display_type: category['type']
          )

          mailchimp_category.save!
        end

        # Destroy any Effective::MailchimpGroups resources if they no longer returned by groups
        mailchimp_categories.each do |mailchimp_category|
          category = categories.find { |category| category['id'] == mailchimp_category.mailchimp_id }
          mailchimp_category.destroy! unless category.present?
        end
      end

      true
    end

    def to_s
      name.presence || model_name.human
    end

  end
end
