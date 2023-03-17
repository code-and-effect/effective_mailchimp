module Effective
  class MailchimpList < ActiveRecord::Base

    self.table_name = (EffectiveMailchimp.mailchimp_lists_table_name || :mailchimp_lists).to_s

    has_many :mailchimp_list_members, dependent: :delete_all

    effective_resource do
      mailchimp_id    :string
      web_id          :string

      name            :string

      can_subscribe   :boolean
      force_subscribe :boolean

      timestamps
    end

    def to_s
      name.presence || model_name.human
    end

    scope :deep, -> { all }
    scope :sorted, -> { order(:name) }
    scope :subscribable, -> { where(can_subscribe: true) }

    # Creates or builds all the Lists
    def self.sync!
      # All the Lists from Mailchimp
      lists = EffectiveMailchimp.api.lists

      # Get all our existing Effective::MailchimpList records
      mailchimp_lists = all()

      # Find or create Effective::Mailchimp based on existing lists
      lists.each do |list|
        mailchimp_id = list['id']
        web_id = list['web_id']
        name = list['name']

        mailchimp_list = mailchimp_lists.find { |ml| ml.mailchimp_id == mailchimp_id } || new()
        mailchimp_list.assign_attributes(mailchimp_id: mailchimp_id, web_id: web_id, name: name)
        mailchimp_list.save!
      end

      # Destroy any Effective::Mailchimp resources if they no longer returned by lists
      mailchimp_lists.each do |mailchimp_list|
        list = lists.find { |list| list['id'] == mailchimp_list.mailchimp_id }
        mailchimp_list.destroy! unless list.present?
      end

      true
    end

    # This creates our local merge fields ON Mailchimp
    def create_mailchimp_merge_fields!(merge_fields)
      raise('expected a Hash of merge fields') unless merge_fields.kind_of?(Hash)

      merge_fields.keys.each do |name|
        EffectiveMailchimp.api.add_merge_field(mailchimp_id, name: name)
      end

      true
    end

    def merge_fields
      return [] unless mailchimp_id
      EffectiveMailchimp.api.list_merge_fields(mailchimp_id).map { |hash| hash['tag'] }.sort
    end

    def url
      EffectiveMailchimp.api.admin_url + "/campaigns/#f_list:#{web_id}"
    end

    def members_url
      EffectiveMailchimp.api.admin_url + "/lists/members?id=#{web_id}"
    end

    def merge_fields_url
      EffectiveMailchimp.api.admin_url + "/lists/settings/merge-tags?id=#{web_id}"
    end

    def can_subscribe!
      update!(can_subscribe: true)
    end

    def cannot_subscribe!
      update!(can_subscribe: false)
    end

    def force_subscribe!
      update!(force_subscribe: true)
    end

    def unforce_subscribe!
      update!(force_subscribe: false)
    end

  end
end
