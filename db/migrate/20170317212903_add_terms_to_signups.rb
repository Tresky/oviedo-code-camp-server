class AddTermsToSignups < ActiveRecord::Migration
  def change
    add_column :signups, :terms_agreed, :boolean
  end
end
