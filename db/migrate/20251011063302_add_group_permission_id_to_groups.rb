class AddGroupPermissionIdToGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :groups, :group_permission_id, :integer
  end
end
