class RemoveRoleFromUserGroups < ActiveRecord::Migration[7.0]
  def change
    if column_exists?(:user_groups, :role)
      remove_column :user_groups, :role
    end
  end
end
