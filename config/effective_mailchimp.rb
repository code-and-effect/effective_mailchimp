EffectiveMailchimp.setup do |config|
  # config.mailchimp_table_name = :mailchimp
  # Layout Settings
  # Configure the Layout per controller, or all at once
  # config.layout = { application: 'application', admin: 'admin' }

  # Mailchimp Settings
  # Configure the class responsible for the mailchimp.
  # This should extend from Effective::Mailchimp
  # config.mailchimp_class_name = 'Effective::Mailchimp'

  # Mailer Settings
  # Please see config/initializers/effective_mailchimp.rb for default effective_* gem mailer settings
  #
  # Configure the class responsible to send e-mails.
  # config.mailer = 'Effective::MailchimpMailer'
  #
  # Override effective_resource mailer defaults
  #
  # config.parent_mailer = nil      # The parent class responsible for sending emails
  # config.deliver_method = nil     # The deliver method, deliver_later or deliver_now
  # config.mailer_layout = nil      # Default mailer layout
  # config.mailer_sender = nil      # Default From value
  # config.mailer_admin = nil       # Default To value for Admin correspondence
  # config.mailer_subject = nil     # Proc.new method used to customize Subject

  # Will work with effective_email_templates gem
  config.use_effective_email_templates = true
end
