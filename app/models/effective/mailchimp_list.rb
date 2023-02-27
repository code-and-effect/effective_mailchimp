module Effective
  class MailchimpList < ActiveRecord::Base

    self.table_name = (EffectiveMailchimp.mailchimp_lists_table_name || :mailchimp_lists).to_s

    effective_resource do
      mailchimp_id    :string
      name            :string
      subscribable    :boolean

      timestamps
    end

    def to_s
      name.presence || model_name.human
    end

  end
end
