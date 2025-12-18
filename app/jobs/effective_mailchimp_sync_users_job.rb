class EffectiveMailchimpSyncUsersJob < ApplicationJob
  def perform(user_class_name)
    users = user_class_name.safe_constantize
    raise('expected an effective_mailchimp_user class') unless users.try(:effective_mailchimp_user?)
    raise('expected a mailchimp API key') unless EffectiveMailchimp.api_present?

    api = EffectiveMailchimp.api

    EffectiveLogger.info("Starting sync users from mailchimp job")

    users.find_each do |user|
      begin
        puts "Mailchimp sync user #{user.id}"
        user.mailchimp_sync!(api: api)
        user.mailchimp_update!(api: api)
      rescue => e
        EffectiveLogger.error(e.message, associated: user) if defined?(EffectiveLogger)
        ExceptionNotifier.notify_exception(e, data: { user_id: user.id }) if defined?(ExceptionNotifier)
      end
    end

    EffectiveLogger.info("Finished sync users from mailchimp job")
  end
end
