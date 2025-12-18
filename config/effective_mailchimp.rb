EffectiveMailchimp.setup do |config|
  # Layout Settings
  # Configure the Layout per controller, or all at once
  # config.layout = { application: 'application', admin: 'admin' }

  # Mailchimp Settings
  config.api_key = ''  # From mailchimp's /account/api/ screen

  # In Sandbox Mode you can only READ from Mailchimp not actually write to it
  config.sandbox_mode = false

  # Assign the User class name. For use in determining all merge_fields
  # config.user_class_name = 'User'

  config.silence_api_errors = false
end
