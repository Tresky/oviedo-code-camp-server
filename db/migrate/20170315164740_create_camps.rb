class CreateCamps < ActiveRecord::Migration
  def self.up
    create_table :camps do |t|
     t.string :name
     t.integer :num_registered, default: 0
     t.string :registered_signup_ids, array: true, default: []
     t.timestamps
   end
  end

  def self.down
    drop_table :camps
  end
end
