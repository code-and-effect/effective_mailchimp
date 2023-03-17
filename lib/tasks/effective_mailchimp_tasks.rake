namespace :effective_mailchimp do

  # bundle exec rake effective_mailchimp:seed
  task seed: :environment do
    load "#{__dir__}/../../db/seeds.rb"
  end

  # bundle exec rake effective_mailchimp:create_mailchimp_merge_fields
  task create_mailchimp_merge_fields: :environment do
    merge_fields = User.new.mailchimp_merge_fields()

    Effective::MailchimpList.sync!

    collection = Effective::MailchimpList.all

    collection.find_each do |list|
      puts "Creating #{list} merge fields"
      list.create_mailchimp_merge_fields!(merge_fields)
    end

    puts 'All done'
  end

end
