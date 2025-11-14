class AddDeletedColumnsToScheduleLinks < ActiveRecord::Migration[8.0]
  def change
    add_column :schedule_links, :deleted_at, :datetime
    add_column :schedule_links, :deleted_by, :integer
  end
end
