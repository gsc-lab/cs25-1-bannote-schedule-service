class RevertUserColumnsToInteger < ActiveRecord::Migration[7.0]
  def up
    change_column :groups, :created_by, :integer
    change_column :groups, :updated_by, :integer
    change_column :groups, :deleted_by, :integer

    change_column :user_groups, :user_id, :integer
    change_column :group_updates, :user_id, :integer
  end

  def down
    change_column :groups, :created_by, :string
    change_column :groups, :updated_by, :string
    change_column :groups, :deleted_by, :string

    change_column :user_groups, :user_id, :string
    change_column :group_updates, :user_id, :string
  end
end
