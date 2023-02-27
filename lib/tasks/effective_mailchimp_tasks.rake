namespace :effective_mailchimp do

  # bundle exec rake effective_mailchimp:seed
  task seed: :environment do
    load "#{__dir__}/../../db/seeds.rb"
  end

end
