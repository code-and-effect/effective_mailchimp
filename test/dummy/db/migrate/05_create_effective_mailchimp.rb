class CreateEffectiveMailchimp < ActiveRecord::Migration[4.2]
  def change

    create_table :mailchimp_lists do |t|
      t.string :mailchimp_id
      t.string :web_id

      t.string :name
      t.boolean :can_subscribe

      t.timestamps
    end

  end
end
