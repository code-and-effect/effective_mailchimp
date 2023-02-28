EffectiveMailchimp.setup do |config|
  # config.mailchimp_lists_table_name = :mailchimp_lists
  # config.mailchimp_list_members_table_name = :mailchimp_list_members

  # Layout Settings
  # Configure the Layout per controller, or all at once
  # config.layout = { application: 'application', admin: 'admin' }

  # Mailchimp Settings
  config.api_key = ''  # From mailchimp's /account/api/ screen
  config.server = ''   # Determine from your mailchimp account URL. Something like us1
end
