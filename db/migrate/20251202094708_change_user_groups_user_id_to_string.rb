class ChangeUserGroupsUserIdToString < ActiveRecord::Migration[7.1]
  def change
    change_column :user_groups, :user_id, :string
  end
end
