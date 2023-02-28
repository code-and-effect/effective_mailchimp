# Effective Mailchimp

Subscribe and unsubscribe users to individual mailchimp campaigns.

Update Mailchimp whenever a user changes their demographics

## Getting Started

This requires Rails 6+ and Twitter Bootstrap 4 and just works with Devise.

Please first install the [effective_datatables](https://github.com/code-and-effect/effective_datatables) gem.

Please download and install the [Twitter Bootstrap4](http://getbootstrap.com)

Add to your Gemfile:

```ruby
gem 'haml'
gem 'effective_mailchimp'
```

Run the bundle command to install it:

```console
bundle install
```

Then run the generator:

```ruby
rails generate effective_mailchimp:install
```

The generator will install an initializer which describes all configuration options and creates a database migration.

If you want to tweak the table names, manually adjust both the configuration file and the migration now.

Then migrate the database:

```ruby
rake db:migrate
```

Please add the following to your User model:

```
effective_mailchimp_user
```

and

Add a link to the admin menu:

```haml
- if can? :admin, :effective_mailchimp
  - if can? :index, Effective::MailchimpList
    = nav_link_to 'Mailchimp lists', effective_mailchimp.admin_mailchimp_lists_path
```

To add the fields to your existing users form

```
= form_with(model: user) do |f|
  = f.text_field :first_name
  = f.text_field :last_name
  = mailchimp_user_fields(f)
  = f.submit
```

## Configuring Mailchimp Account

Refer to the Marketing API Quick Start

`https://mailchimp.com/developer/marketing/guides/quick-start/`

Sign up for a Mailchimp account. Create a campaign.

Get API key from:

Visit `https://us7.admin.mailchimp.com/account/api/`

Click Create an API Key

Get your server from the domain. us7 in the above example.

## Configuration

## Authorization

All authorization checks are handled via the effective_resources gem found in the `config/initializers/effective_resources.rb` file.

## Permissions

The permissions you actually want to define are as follows (using CanCan):

```ruby
if user.persisted?
end

if user.admin?
  can :admin, :effective_mailchimp

  can([:index, :edit, :update], Effective::MailchimpList)
  can(:can_subscribe, Effective::MailchimpList) { |list| !list.can_subscribe? }
  can(:cannot_subscribe, Effective::MailchimpList) { |list| list.can_subscribe? }
end
```

## License

MIT License. Copyright [Code and Effect Inc.](http://www.codeandeffect.com/)

## Testing

Run tests by:

```ruby
rails test
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Bonus points for test coverage
6. Create new Pull Request
