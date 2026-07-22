class ChangeCreatedByColumnsToString < ActiveRecord::Migration[7.0]
  def change
    # schedule_links
    change_column :schedule_links, :created_by, :string

    # schedules
    change_column :schedules, :created_by, :string

    # groups
    change_column :groups, :created_by, :string
    change_column :groups, :updated_by, :string
    change_column :groups, :deleted_by, :string
  end
end
