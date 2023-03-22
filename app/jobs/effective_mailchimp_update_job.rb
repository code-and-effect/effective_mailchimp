class EffectiveMailchimpUpdateJob < ApplicationJob

  def perform(user)
    raise('expected an effective_mailchimp_user') unless user.class.try(:effective_mailchimp_user?)
    user.mailchimp_update!(force: true)
  end

end
