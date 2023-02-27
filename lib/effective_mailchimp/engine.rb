module EffectiveMailchimp
  class Engine < ::Rails::Engine
    engine_name 'effective_mailchimp'

    # Set up our default configuration options.
    initializer 'effective_mailchimp.defaults', before: :load_config_initializers do |app|
      eval File.read("#{config.root}/config/effective_mailchimp.rb")
    end

    # Include acts_as_mailchimp concern and allow any ActiveRecord object to call it
    initializer 'effective_mailchimp.active_record' do |app|
      app.config.to_prepare do
        #ActiveRecord::Base.extend(ActsAsMailchimp::Base)
      end
    end

  end
end
