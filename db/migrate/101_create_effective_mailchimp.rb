class CreateEffectiveMailchimp < ActiveRecord::Migration[6.0]
  def change
    create_table :mailchimp_lists do |t|
      t.string :mailchimp_id
      t.string :web_id
      t.string :name

      t.boolean :can_subscribe
      t.boolean :force_subscribe

      t.timestamps
    end

    create_table :mailchimp_list_members do |t|
      t.integer :user_id
      t.string :user_type

      t.integer :mailchimp_list_id

      t.string :mailchimp_id
      t.string :web_id

      t.string :email_address
      t.string :full_name

      t.boolean :subscribed, default: false
      t.boolean :cannot_be_subscribed, default: false

      t.datetime :last_synced_at

      t.timestamps
    end

  end
end
