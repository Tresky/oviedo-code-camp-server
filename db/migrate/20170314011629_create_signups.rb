class CreateSignups < ActiveRecord::Migration
  def self.up
    create_table :signups do |t|
     t.string :email
     t.string :parent_first_name
     t.string :parent_last_name
     t.string :child_first_name
     t.string :child_last_name
     t.integer :child_completed_grade
     t.string :child_tshirt_size
     t.integer :camp_selection
     t.timestamps
   end
  end

  def self.down
    drop_table :signups
  end
end
