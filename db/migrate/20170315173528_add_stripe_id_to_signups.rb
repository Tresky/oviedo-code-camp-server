class AddStripeIdToSignups < ActiveRecord::Migration
  def change
    add_column :signups, :stripe_id, :string
  end
end
