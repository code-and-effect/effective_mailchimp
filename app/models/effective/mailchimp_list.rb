module Effective
  class MailchimpList < ActiveRecord::Base
    self.table_name = (EffectiveMailchimp.mailchimp_lists_table_name || :mailchimp_lists).to_s

    has_many :mailchimp_list_members, dependent: :delete_all
    has_many :mailchimp_categories, dependent: :delete_all
    has_many :mailchimp_interests, dependent: :delete_all

    effective_resource do
      mailchimp_id    :string
      web_id          :string

      name            :string

      can_subscribe   :boolean
      force_subscribe :boolean

      timestamps
    end

    scope :deep, -> { includes(:mailchimp_categories, :mailchimp_interests) }
    scope :sorted, -> { order(:name) }
    scope :subscribable, -> { where(can_subscribe: true) }

    # Creates or builds all the Lists
    def self.sync!(api: EffectiveMailchimp.api, merge_fields: nil)
      # All the Lists from Mailchimp
      lists = api.lists()

      # Get all our existing Effective::MailchimpList records
      mailchimp_lists = all()

      # Find or create Effective::Mailchimp based on existing lists
      lists.each do |list|
        mailchimp_id = list['id']

        mailchimp_list = mailchimp_lists.find { |ml| ml.mailchimp_id == mailchimp_id } || new()
        mailchimp_list.assign_attributes(
          mailchimp_id: mailchimp_id,

          web_id: list['web_id'],
          name: list['name'],
          updated_at: Time.zone.now
        )

        mailchimp_list.assign_attributes(can_subscribe: true) if mailchimp_list.new_record?
        mailchimp_list.save!
      end

      # Destroy any Effective::Mailchimp resources if they no longer returned by lists
      mailchimp_lists.each do |mailchimp_list|
        list = lists.find { |list| list['id'] == mailchimp_list.mailchimp_id }
        mailchimp_list.destroy! unless list.present?
      end

      # Sync merge fields
      if merge_fields.present?
        merge_field_keys = merge_fields.keys.map(&:to_s)

        mailchimp_lists.reject(&:destroyed?).each do |mailchimp_list|
          existing = api.list_merge_fields(mailchimp_list).map { |hash| hash['tag'] }
          (merge_field_keys - existing).each do |name| 
            puts "Adding merge field #{name} to #{mailchimp_list}"
            api.add_merge_field(mailchimp_list, name: name)
          end
        end
      end

      true
    end

    def to_s
      name.presence || model_name.human
    end

    def merge_fields
      return [] unless mailchimp_id
      EffectiveMailchimp.api.list_merge_fields(mailchimp_id).map { |hash| hash['tag'] }.sort
    end

    def grouped?
      mailchimp_categories.present? && mailchimp_categories.any? { |category| category.mailchimp_interests.present? }
    end

    def ungrouped?
      !grouped?
    end

    def members_url
      EffectiveMailchimp.api.admin_url + "/lists/members?id=#{web_id}"
    end

    def merge_fields_url
      EffectiveMailchimp.api.admin_url + "/lists/settings/merge-tags?id=#{web_id}"
    end

  end
end
