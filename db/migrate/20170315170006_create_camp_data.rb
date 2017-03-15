class CreateCampData < ActiveRecord::Migration
  def up
    Camp.create(:name => 'foundations-elem-1')
    Camp.create(:name => 'foundations-elem-2')
    Camp.create(:name => 'foundations-middle-1')
    Camp.create(:name => 'foundations-middle-2')
  end

  def down
    Camp.delete_all
  end
end
