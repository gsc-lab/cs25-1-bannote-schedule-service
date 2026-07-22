class AddRoleToUserGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :user_groups, :role, :integer, default: 0, null: false
  end
end
