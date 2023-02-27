require 'effective_resources'
require 'effective_datatables'
require 'effective_mailchimp/engine'
require 'effective_mailchimp/version'

module EffectiveMailchimp

  def self.config_keys
    [
      :layout,
      :mailer, :parent_mailer, :deliver_method, :mailer_layout, :mailer_sender, :mailer_admin, :mailer_subject, :use_effective_email_templates
    ]
  end

  include EffectiveGem

end
