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

  end
end
