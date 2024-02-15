module Effective
  class MailchimpListMember < ActiveRecord::Base
    self.table_name = (EffectiveMailchimp.mailchimp_list_members_table_name || :mailchimp_list_members).to_s

    belongs_to :user, polymorphic: true
    belongs_to :mailchimp_list

    log_changes(to: :user, except: :last_synced_at) if respond_to?(:log_changes)

    effective_resource do
      mailchimp_id    :string
      web_id          :string

      email_address   :string
      full_name       :string

      # We set this on our side to update mailchimp and subscribe the user
      subscribed              :boolean

      # This one is generated by the MailchimpMarketing::ApiError
      # They unsubscribed and there's nothing we can do about it.
      cannot_be_subscribed    :boolean # Member is in Compliance State

      last_synced_at  :datetime

      timestamps
    end

    validates :mailchimp_list_id, uniqueness: { scope: [:user_type, :user_id] }

    scope :deep, -> { includes(:mailchimp_list, :user) }
    scope :sorted, -> { order(:id) }

    def to_s
      mailchimp_list&.to_s || model_name.human
    end

    def email
      email_address.presence || user.email
    end

    def assign_mailchimp_attributes(atts)
      assign_attributes(
        mailchimp_id: atts['id'],
        web_id: atts['web_id'],
        email_address: atts['email_address'],
        full_name: atts['full_name'],
        subscribed: (atts['status'] == 'subscribed'),
        last_synced_at: Time.zone.now
      )
    end

    def assign_mailchimp_cannot_be_subscribed
      assign_attributes(
        subscribed: false,
        cannot_be_subscribed: true,
        last_synced_at: Time.zone.now
      )
    end

    def synced?
      last_synced_at.present?
    end

  end
end
